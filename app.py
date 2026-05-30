import os
import logging
import sqlite3
from logging.handlers import RotatingFileHandler
from flask import Flask, request, jsonify
from twilio.rest import Client
from dotenv import load_dotenv
from datetime import datetime
import pytz

# --- CONFIGURACIÓN DE LOGGING ---
log_formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
log_file = 'mama_notifier.log'
# Forzamos encoding UTF-8 para evitar caracteres extraños en los logs
file_handler = RotatingFileHandler(log_file, maxBytes=1024 * 1024, backupCount=5, encoding='utf-8')
file_handler.setFormatter(log_formatter)
console_handler = logging.StreamHandler()
console_handler.setFormatter(log_formatter)
logger = logging.getLogger()
logger.setLevel(logging.INFO)
logger.addHandler(file_handler)
logger.addHandler(console_handler)

load_dotenv()

app = Flask(__name__)

# --- CONFIGURACIÓN DE ZONA HORARIA ---
ARG_TZ = pytz.timezone('America/Argentina/Buenos_Aires')

def obtener_ahora_local():
    """Retorna el objeto datetime actual en la zona horaria de Argentina."""
    return datetime.now(ARG_TZ)

# Configuración de Twilio (con limpieza de espacios/comillas y validación de prefijo)
def normalizar_numero_whatsapp(numero):
    if not numero:
        return ""
    # Limpieza básica
    n = str(numero).strip().replace('"', '').replace("'", "")
    # Asegurar prefijo whatsapp: para evitar error 63007 si se olvida en el .env
    if n and not n.startswith('whatsapp:'):
        return f"whatsapp:{n}"
    return n

TWILIO_ACCOUNT_SID = os.getenv('TWILIO_ACCOUNT_SID', '').strip().replace('"', '').replace("'", "")
TWILIO_AUTH_TOKEN = os.getenv('TWILIO_AUTH_TOKEN', '').strip().replace('"', '').replace("'", "")
TWILIO_WHATSAPP_NUMBER = normalizar_numero_whatsapp(os.getenv('TWILIO_WHATSAPP_NUMBER', ''))
MAMA_WHATSAPP_NUMBER = normalizar_numero_whatsapp(os.getenv('MAMA_WHATSAPP_NUMBER', ''))
WEBHOOK_SECRET_TOKEN = os.getenv('WEBHOOK_SECRET_TOKEN', '').strip()
DB_NAME = 'mama_notifier.db'

# --- DIAGNÓSTICO DE VARIABLES ---
logger.info("--- Diagnóstico de Configuración ---")
logger.info(f"TWILIO_WHATSAPP_NUMBER: {TWILIO_WHATSAPP_NUMBER}")
# Mostramos solo el inicio y fin del número de destino por seguridad
if MAMA_WHATSAPP_NUMBER:
    mask_num = MAMA_WHATSAPP_NUMBER[:15] + "..." + MAMA_WHATSAPP_NUMBER[-2:]
    logger.info(f"MAMA_WHATSAPP_NUMBER cargado: {mask_num}")
else:
    logger.error("MAMA_WHATSAPP_NUMBER no encontrada en .env")
logger.info(f"SID de Twilio cargado (primeros 5): {TWILIO_ACCOUNT_SID[:5]}...")
logger.info(f"Hora actual detectada (Argentina): {obtener_ahora_local().strftime('%Y-%m-%d %H:%M:%S')}")
logger.info("------------------------------------")

# --- LÓGICA DE BASE DE DATOS ---
def init_db():
    """Crea la tabla de historial si no existe."""
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    # Mantenemos el DEFAULT por compatibilidad, pero insertaremos manualmente
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS historial_eventos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tipo_evento TEXT NOT NULL,
            fecha_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            estado_envio BOOLEAN NOT NULL,
            twilio_sid TEXT
        )
    ''')
    conn.commit()
    conn.close()
    logger.info("Base de datos inicializada correctamente.")

def registrar_evento(tipo, estado, sid=None):
    """Guarda el resultado de un evento en la DB con hora local de Argentina."""
    try:
        ahora_local = obtener_ahora_local().strftime("%Y-%m-%d %H:%M:%S")
        conn = sqlite3.connect(DB_NAME)
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO historial_eventos (tipo_evento, fecha_hora, estado_envio, twilio_sid)
            VALUES (?, ?, ?, ?)
        ''', (tipo, ahora_local, estado, sid))
        conn.commit()
        conn.close()
        logger.info(f"Evento registrado en DB: {tipo} a las {ahora_local}")
    except Exception as e:
        logger.error(f"Error al guardar en DB: {e}")

# Inicializar DB al arrancar
init_db()

client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)

def enviar_whatsapp(mensaje):
    try:
        message = client.messages.create(
            from_=TWILIO_WHATSAPP_NUMBER,
            body=mensaje,
            to=MAMA_WHATSAPP_NUMBER
        )
        logger.info(f"Mensaje enviado con éxito. SID: {message.sid}")
        return True, message.sid
    except Exception as e:
        error_msg = str(e)
        if "63007" in error_msg:
            logger.error("Error 63007: Twilio no reconoce el número 'From'.")
            logger.error("Asegúrate de haber activado el Sandbox de WhatsApp en la consola de Twilio para esta cuenta.")
        else:
            logger.error(f"Error crítico en Twilio: {e}")
        return False, None

@app.route('/webhook/<accion>', methods=['POST'])
def webhook(accion):
    # Seguridad
    auth_header = request.headers.get('Authorization')
    if not auth_header or auth_header != f"Bearer {WEBHOOK_SECRET_TOKEN}":
        logger.warning(f"Intento no autorizado desde: {request.remote_addr}")
        return jsonify({"error": "No autorizado"}), 401

    if accion not in ['llegada', 'salida']:
        return jsonify({"error": "Acción no válida"}), 400

    # Lógica de tiempo
    ahora = obtener_ahora_local()
    timestamp_msg = ahora.strftime("%H:%M")
    
    if accion == 'llegada':
        # Mensaje por defecto si no hay variable de entorno
        default_llegada = f"¡Hola Brenda! 👋 Ignacio ya llegó a su trabajo. 💼 ({timestamp_msg}) ✅"
        texto_mensaje = os.getenv('MSG_LLEGADA', default_llegada).replace('{time}', timestamp_msg)
    else:
        # Mensaje por defecto si no hay variable de entorno
        default_salida = f"¡Hola Brenda! ✨ Ignacio está volviendo a casa. 🏠 ({timestamp_msg}) 🏍️💨"
        texto_mensaje = os.getenv('MSG_SALIDA', default_salida).replace('{time}', timestamp_msg)

    logger.info(f"Procesando {accion}...")
    exito, sid = enviar_whatsapp(texto_mensaje)
    
    # PERSISTENCIA: Guardamos todo en la base de datos (con la hora local ya calculada)
    registrar_evento(accion, exito, sid)

    if exito:
        return jsonify({"status": "success", "twilio_sid": sid}), 200
    else:
        return jsonify({"status": "error", "message": "Fallo en el envío"}), 500

if __name__ == '__main__':
    logger.info("Iniciando MAMA-NOTIFIER API con Persistencia...")
    # host='0.0.0.0' es fundamental para Docker
    app.run(debug=True, host='0.0.0.0', port=5000)
