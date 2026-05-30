import os
import logging
import sqlite3
import uuid
from datetime import datetime
from typing import Optional, Dict, List
from fastapi import FastAPI, Header, HTTPException, Depends, status, Request, Form
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel, Field
from twilio.rest import Client
from dotenv import load_dotenv
import pytz

# --- CONFIGURACIÓN ---
load_dotenv()
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("MAMA-NOTIFIER-SAAS")

ARG_TZ = pytz.timezone('America/Argentina/Buenos_Aires')
DB_NAME = 'mama_notifier.db'

# Credenciales maestras de Twilio
TWILIO_ACCOUNT_SID = os.getenv('TWILIO_ACCOUNT_SID', '').strip()
TWILIO_AUTH_TOKEN = os.getenv('TWILIO_AUTH_TOKEN', '').strip()
TWILIO_WHATSAPP_NUMBER = os.getenv('TWILIO_WHATSAPP_NUMBER', '').strip()

app = FastAPI(title="Mama-Notifier SaaS", version="3.0.0")
templates = Jinja2Templates(directory="templates")

# --- MODELOS ---

class LocationData(BaseModel):
    zone_name: str
    timestamp: datetime

class EventPayload(BaseModel):
    user_id: str
    device_id: str
    event_type: str
    location_data: LocationData

# --- DB SETUP ---

def get_db():
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            full_name TEXT,
            email TEXT UNIQUE,
            api_token TEXT UNIQUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS contacts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT,
            contact_name TEXT,
            phone_number TEXT,
            msg_llegada TEXT,
            msg_salida TEXT,
            FOREIGN KEY(user_id) REFERENCES users(id)
        )
    ''')
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS notification_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT,
            event_type TEXT,
            recipient TEXT,
            status TEXT,
            twilio_sid TEXT,
            timestamp TEXT
        )
    ''')
    
    # --- MIGRACIONES MANUALES (Para DBs existentes) ---
    try:
        cursor.execute("ALTER TABLE users ADD COLUMN email TEXT UNIQUE")
    except: pass
    try:
        cursor.execute("ALTER TABLE contacts ADD COLUMN msg_llegada TEXT")
        cursor.execute("ALTER TABLE contacts ADD COLUMN msg_salida TEXT")
    except: pass

    conn.commit()
    conn.close()

init_db()

# --- SEGURIDAD ---

async def get_current_user(request: Request):
    # Intentar obtener token de la cabecera (App Móvil) o de la Cookie (Dashboard)
    auth = request.headers.get("Authorization")
    token = None
    
    if auth and auth.startswith("Bearer "):
        token = auth.split(" ")[1]
    else:
        token = request.cookies.get("session_token")
    
    if not token:
        return None

    conn = get_db()
    user = conn.execute("SELECT * FROM users WHERE api_token = ?", (token,)).fetchone()
    conn.close()
    return user

# --- MOTOR DE TWILIO ---

def send_whatsapp(to_phone: str, body: str):
    if not TWILIO_ACCOUNT_SID or not TWILIO_AUTH_TOKEN:
        logger.warning(f"Simulando WhatsApp a {to_phone}: {body}")
        return "SIM_SID_" + str(uuid.uuid4())[:8]
    
    client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
    target = to_phone if to_phone.startswith('whatsapp:') else f"whatsapp:{to_phone}"
    message = client.messages.create(from_=TWILIO_WHATSAPP_NUMBER, body=body, to=target)
    return message.sid

# --- RUTAS DASHBOARD & REGISTRO ---

@app.get("/", response_class=HTMLResponse)
async def home(request: Request, user=Depends(get_current_user)):
    if not user:
        return templates.TemplateResponse(request=request, name="login.html")
    
    conn = get_db()
    contacts = conn.execute("SELECT * FROM contacts WHERE user_id = ?", (user["id"],)).fetchall()
    logs = conn.execute("SELECT * FROM notification_logs WHERE user_id = ? ORDER BY id DESC LIMIT 10", (user["id"],)).fetchall()
    conn.close()
    
    return templates.TemplateResponse(
        request=request, 
        name="dashboard.html", 
        context={
            "user": user, 
            "contacts": contacts, 
            "logs": logs
        }
    )

@app.post("/register")
async def register(name: str = Form(...), email: str = Form(...)):
    user_id = str(uuid.uuid4())[:8]
    api_token = "mama_" + str(uuid.uuid4()).replace("-", "")[:16]
    
    try:
        conn = get_db()
        conn.execute("INSERT INTO users (id, full_name, email, api_token) VALUES (?, ?, ?, ?)",
                     (user_id, name, email, api_token))
        conn.commit()
        conn.close()
        response = RedirectResponse(url="/", status_code=status.HTTP_303_SEE_OTHER)
        response.set_cookie(key="session_token", value=api_token)
        return response
    except Exception as e:
        return f"Error: El email ya existe o hubo un fallo en la DB. {e}"

@app.post("/contacts/add")
async def add_contact(
    name: str = Form(...), 
    phone: str = Form(...),
    msg_llegada: str = Form("¡Hola! {user} llegó a su destino. ✅"),
    msg_salida: str = Form("¡Hola! {user} está volviendo. 🏠"),
    user=Depends(get_current_user)
):
    if not user:
        raise HTTPException(status_code=401, detail="No autorizado")

    u_name = user["full_name"]
    conn = get_db()
    
    # 1. Guardar contacto con sus mensajes personalizados
    conn.execute('''
        INSERT INTO contacts (user_id, contact_name, phone_number, msg_llegada, msg_salida)
        VALUES (?, ?, ?, ?, ?)
    ''', (user["id"], name, phone, msg_llegada, msg_salida))
    conn.commit()
    conn.close()

    # 2. Enviar mensaje de VINCULACIÓN (Onboarding del contacto)
    link_msg = f"🔔 ¡Hola {name}! {u_name} te ha agregado a su red de seguridad en Mama-Notifier. Recibirás un aviso por aquí cuando llegue o salga de sus zonas seguras. ✨"
    send_whatsapp(phone, link_msg)
    
    return RedirectResponse(url="/", status_code=status.HTTP_303_SEE_OTHER)

@app.get("/logout")
async def logout():
    response = RedirectResponse(url="/")
    response.delete_cookie("session_token")
    return response

# --- RUTAS DE SIMULACIÓN Y API (Actualizadas con mensajes personalizados) ---

@app.get("/simulate/{event_type}")
async def simulate_event(event_type: str, user=Depends(get_current_user)):
    if not user: raise HTTPException(status_code=401)
    
    conn = get_db()
    contacts = conn.execute("SELECT * FROM contacts WHERE user_id = ?", (user["id"],)).fetchall()
    
    ahora = datetime.now(ARG_TZ)
    time_str = ahora.strftime("%H:%M")
    
    for c in contacts:
        template = c["msg_llegada"] if event_type == "llegada" else c["msg_salida"]
        mensaje = template.replace("{user}", user["full_name"]).replace("{time}", time_str)
        
        sid = send_whatsapp(c["phone_number"], mensaje)
        
        conn.execute('''
            INSERT INTO notification_logs (user_id, event_type, recipient, status, twilio_sid, timestamp)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (user["id"], f"SIM_{event_type}", c["contact_name"], "sent", sid, ahora.isoformat()))
    
    conn.commit()
    conn.close()
    return RedirectResponse(url="/", status_code=status.HTTP_303_SEE_OTHER)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5000)
