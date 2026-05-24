# 🚀 MAMA-Notifier (WhatsApp)

Un sistema de notificaciones automático diseñado para enviar avisos de llegada y salida a través de WhatsApp (vía Twilio). Ideal para mantener a la familia informada sobre estados de traslado con un solo clic/webhook, integrando persistencia en base de datos y manejo preciso de horarios.

## ✨ Características
- **Notificaciones instantáneas:** Envía mensajes personalizados a través de la API de WhatsApp de Twilio.
- **Persistencia de datos:** Registra cada evento (llegada/salida) en una base de datos SQLite con éxito/fallo y SID de Twilio.
- **Manejo de Horarios:** Configurado específicamente para la zona horaria de **Argentina (UTC-3)**, asegurando que los timestamps en los mensajes y la DB sean siempre precisos.
- **Dockerizado:** Fácil de desplegar en cualquier entorno mediante Docker y Docker Compose.
- **Seguridad:** Protección de endpoints mediante tokens Bearer.
- **Logs robustos:** Rotación de archivos de log con soporte para caracteres especiales (UTF-8).

## 🛠️ Stack Tecnológico
- **Lenguaje:** Python 3.11
- **Framework Web:** Flask
- **Base de Datos:** SQLite
- **Comunicación:** Twilio (WhatsApp Business API)
- **Despliegue:** Docker / Docker Compose / ngrok

## 🚀 Configuración e Instalación

### 1. Requisitos Previos
- Docker y Docker Compose instalados.
- Cuenta de [Twilio](https://www.twilio.com/) con el Sandbox de WhatsApp activo.
- [ngrok](https://ngrok.com/) para exponer el servidor local (opcional para desarrollo).

### 2. Variables de Entorno
Crea un archivo `.env` en la raíz del proyecto basado en `.env.example`:
```env
TWILIO_ACCOUNT_SID=tu_sid_aqui
TWILIO_AUTH_TOKEN=tu_token_aqui
TWILIO_WHATSAPP_NUMBER=whatsapp:+14155238886
MAMA_WHATSAPP_NUMBER=whatsapp:+549...
WEBHOOK_SECRET_TOKEN=tu_token_seguro
```

### 3. Despliegue con Docker
Construye y levanta el servicio:
```bash
docker-compose up --build -d
```

### 4. Uso del Webhook
El sistema expone dos acciones principales:
- `POST /webhook/llegada`
- `POST /webhook/salida`

**Ejemplo de llamada con cURL:**
```bash
curl -X POST http://tu-url.ngrok.io/webhook/llegada \
     -H "Authorization: Bearer tu_token_seguro"
```

## 📝 Estructura de la Base de Datos
La tabla `historial_eventos` almacena:
- `id`: Identificador único.
- `tipo_evento`: 'llegada' o 'salida'.
- `fecha_hora`: Timestamp exacto (Argentina).
- `estado_envio`: Booleano (éxito/fallo).
- `twilio_sid`: ID de rastreo del mensaje de Twilio.

## 🇦🇷 Notas sobre el Horario
El sistema fuerza el uso de `America/Argentina/Buenos_Aires` tanto para el texto de los mensajes como para el almacenamiento en SQLite, evitando desajustes por el reloj del servidor (UTC).

---
Desarrollado con ❤️ para mantener a la familia comunicada.
