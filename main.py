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
import bcrypt
from jose import JWTError, jwt

# --- CONFIGURACIÓN JWT ---
load_dotenv()

# --- CONFIGURACIÓN JWT ---
SECRET_KEY = os.getenv("JWT_SECRET_KEY", "super_secreto_para_desarrollo_cambiame")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 1 semana para el móvil

def create_access_token(data: dict):
    to_encode = data.copy()
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def decode_access_token(token: str):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        return None

# --- CONFIGURACIÓN ---
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("MAMA-NOTIFIER-SAAS")

ARG_TZ = pytz.timezone('America/Argentina/Buenos_Aires')
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_NAME = os.path.join(BASE_DIR, 'mama_notifier.db')

# Credenciales maestras de Twilio
TWILIO_ACCOUNT_SID = os.getenv('TWILIO_ACCOUNT_SID', '').strip()
TWILIO_AUTH_TOKEN = os.getenv('TWILIO_AUTH_TOKEN', '').strip()
# IMPORTANTE: TWILIO_WHATSAPP_NUMBER debe ser el número de Twilio (ej: whatsapp:+14155238886)
TWILIO_WHATSAPP_NUMBER = os.getenv('TWILIO_WHATSAPP_NUMBER', '').strip()

app = FastAPI(title="Mama-Notifier SaaS", version="3.1.0")
templates = Jinja2Templates(directory="templates")

# Seguridad - Hash de contraseñas
def get_password_hash(password):
    pwd_bytes = password.encode('utf-8')
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(pwd_bytes, salt).decode('utf-8')

def verify_password(plain_password, hashed_password):
    try:
        password_byte_enc = plain_password.encode('utf-8')
        hashed_password_byte_enc = hashed_password.encode('utf-8')
        return bcrypt.checkpw(password_byte_enc, hashed_password_byte_enc)
    except Exception as e:
        logger.error(f"Error verificando password: {e}")
        return False

# --- MODELOS ---

class LocationData(BaseModel):
    zone_name: str
    timestamp: datetime

class EventPayload(BaseModel):
    user_id: str
    device_id: str
    event_type: str
    location_data: LocationData

class UserRegister(BaseModel):
    full_name: str
    email: str
    password: str

class ContactBase(BaseModel):
    contact_name: str
    phone_number: str
    msg_llegada: Optional[str] = "¡Hola! {user} llegó a su destino. ✅"
    msg_salida: Optional[str] = "¡Hola! {user} está volviendo. 🏠"

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
            password_hash TEXT,
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
    
    # --- MIGRACIONES MANUALES ---
    try:
        cursor.execute("ALTER TABLE users ADD COLUMN password_hash TEXT")
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
    auth = request.headers.get("Authorization")
    token = None

    if auth and auth.startswith("Bearer "):
        token = auth.split(" ")[1]
        # Intentar decodificar como JWT (App Móvil)
        payload = decode_access_token(token)
        if payload:
            conn = get_db()
            user = conn.execute("SELECT * FROM users WHERE id = ?", (payload.get("sub"),)).fetchone()
            conn.close()
            return user
    else:
        # Intentar obtener de la Cookie (Dashboard)
        token = request.cookies.get("session_token")

    if not token:
        return None

    conn = get_db()
    # Compatibilidad con token estático (api_token) para el dashboard
    user = conn.execute("SELECT * FROM users WHERE api_token = ?", (token,)).fetchone()
    conn.close()
    return user

# --- RUTAS API (MÓVIL & GENERAL) ---

@app.post("/api/v1/register")
async def api_register(payload: UserRegister):
    user_id = str(uuid.uuid4())[:8]
    api_token = "mama_" + str(uuid.uuid4()).replace("-", "")[:16]
    pw_hash = get_password_hash(payload.password)
    
    try:
        conn = get_db()
        conn.execute("INSERT INTO users (id, full_name, email, password_hash, api_token) VALUES (?, ?, ?, ?, ?)",
                     (user_id, payload.full_name, payload.email.lower(), pw_hash, api_token))
        conn.commit()
        conn.close()
        
        # Generar token inmediato para loguear tras registro
        access_token = create_access_token(data={"sub": user_id})
        return {
            "status": "success",
            "access_token": access_token,
            "token_type": "bearer",
            "user": {
                "id": user_id,
                "full_name": payload.full_name,
                "email": payload.email.lower()
            }
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"El email ya existe o hubo un error: {e}")

@app.get("/api/v1/contacts")
async def api_get_contacts(user=Depends(get_current_user)):
    if not user: raise HTTPException(status_code=401)
    conn = get_db()
    contacts = conn.execute("SELECT * FROM contacts WHERE user_id = ?", (user["id"],)).fetchall()
    conn.close()
    return contacts

@app.post("/api/v1/contacts")
async def api_add_contact(payload: ContactBase, user=Depends(get_current_user)):
    if not user: raise HTTPException(status_code=401)
    conn = get_db()
    cursor = conn.execute('''
        INSERT INTO contacts (user_id, contact_name, phone_number, msg_llegada, msg_salida)
        VALUES (?, ?, ?, ?, ?)
    ''', (user["id"], payload.contact_name, payload.phone_number, payload.msg_llegada, payload.msg_salida))
    contact_id = cursor.lastrowid
    conn.commit()
    conn.close()

    # Enviar mensaje de vinculación
    link_msg = f"🔔 ¡Hola {payload.contact_name}! {user['full_name']} te ha agregado a su red de seguridad en Mama-Notifier. Recibirás un aviso por aquí cuando llegue o salga de sus zonas seguras. ✨"
    send_whatsapp(payload.phone_number, link_msg)

    return {"status": "created", "id": contact_id}

@app.delete("/api/v1/contacts/{contact_id}")
async def api_delete_contact(contact_id: int, user=Depends(get_current_user)):
    if not user: raise HTTPException(status_code=401)
    conn = get_db()
    conn.execute("DELETE FROM contacts WHERE id = ? AND user_id = ?", (contact_id, user["id"]))
    conn.commit()
    conn.close()
    return {"status": "deleted"}

@app.get("/api/v1/logs")
async def api_get_logs(user=Depends(get_current_user)):
    if not user: raise HTTPException(status_code=401)
    conn = get_db()
    logs = conn.execute("SELECT * FROM notification_logs WHERE user_id = ? ORDER BY id DESC LIMIT 20", (user["id"],)).fetchall()
    conn.close()
    return logs

class LoginAppRequest(BaseModel):
    email: str
    password: str

@app.post("/api/v1/login")
async def login_app(payload: LoginAppRequest):
    conn = get_db()
    user = conn.execute("SELECT * FROM users WHERE email = ?", (payload.email.lower(),)).fetchone()
    conn.close()

    if user and verify_password(payload.password, user["password_hash"]):
        access_token = create_access_token(data={"sub": user["id"]})
        return {
            "access_token": access_token,
            "token_type": "bearer",
            "user": {
                "id": user["id"],
                "full_name": user["full_name"],
                "email": user["email"]
            }
        }

    raise HTTPException(status_code=401, detail="Credenciales inválidas")


def send_whatsapp(to_phone: str, body: str):
    if not TWILIO_ACCOUNT_SID or not TWILIO_AUTH_TOKEN or not TWILIO_WHATSAPP_NUMBER:
        logger.warning(f"Simulando WhatsApp a {to_phone}: {body}")
        return "SIM_SID_" + str(uuid.uuid4())[:8]
    
    try:
        client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
        # Asegurar prefijo whatsapp:
        target = to_phone if to_phone.startswith('whatsapp:') else f"whatsapp:{to_phone}"
        message = client.messages.create(from_=TWILIO_WHATSAPP_NUMBER, body=body, to=target)
        return message.sid
    except Exception as e:
        logger.error(f"Error enviando Twilio: {e}")
        return f"ERROR_{str(uuid.uuid4())[:4]}"

# --- RUTAS DASHBOARD ---

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
async def register(name: str = Form(...), email: str = Form(...), password: str = Form(...)):
    user_id = str(uuid.uuid4())[:8]
    api_token = "mama_" + str(uuid.uuid4()).replace("-", "")[:16]
    pw_hash = get_password_hash(password)
    
    try:
        conn = get_db()
        conn.execute("INSERT INTO users (id, full_name, email, password_hash, api_token) VALUES (?, ?, ?, ?, ?)",
                     (user_id, name, email.lower(), pw_hash, api_token))
        conn.commit()
        conn.close()
        response = RedirectResponse(url="/", status_code=status.HTTP_303_SEE_OTHER)
        response.set_cookie(key="session_token", value=api_token)
        return response
    except Exception as e:
        return f"Error: El email ya existe o hubo un fallo en la DB. {e}"

@app.post("/login")
async def login(email: str = Form(...), password: str = Form(...)):
    conn = get_db()
    user = conn.execute("SELECT * FROM users WHERE email = ?", (email.lower(),)).fetchone()
    conn.close()
    
    if user and verify_password(password, user["password_hash"]):
        response = RedirectResponse(url="/", status_code=status.HTTP_303_SEE_OTHER)
        response.set_cookie(key="session_token", value=user["api_token"])
        return response
    
    return "Error: Credenciales inválidas."

@app.get("/logout")
async def logout():
    response = RedirectResponse(url="/")
    response.delete_cookie("session_token")
    return response

# --- GESTIÓN DE CONTACTOS ---

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
    
    # 1. Guardar contacto
    conn.execute('''
        INSERT INTO contacts (user_id, contact_name, phone_number, msg_llegada, msg_salida)
        VALUES (?, ?, ?, ?, ?)
    ''', (user["id"], name, phone, msg_llegada, msg_salida))
    conn.commit()
    conn.close()

    # 2. Enviar mensaje de VINCULACIÓN
    link_msg = f"🔔 ¡Hola {name}! {u_name} te ha agregado a su red de seguridad en Mama-Notifier. Recibirás un aviso por aquí cuando llegue o salga de sus zonas seguras. ✨"
    send_whatsapp(phone, link_msg)
    
    return RedirectResponse(url="/", status_code=status.HTTP_303_SEE_OTHER)

@app.get("/contacts/edit/{contact_id}")
async def edit_contact_page(contact_id: int, request: Request, user=Depends(get_current_user)):
    if not user:
        raise HTTPException(status_code=401)

    conn = get_db()
    contact = conn.execute("SELECT * FROM contacts WHERE id = ? AND user_id = ?", (contact_id, user["id"])).fetchone()
    conn.close()

    if not contact:
        raise HTTPException(status_code=404, detail="Contacto no encontrado")

    return templates.TemplateResponse(
        "contact_edit.html",
        {
            "request": request,
            "user": user,
            "contact": contact
        }
    )

@app.post("/contacts/edit/{contact_id}")
async def edit_contact(
    contact_id: int,
    name: str = Form(...),
    phone: str = Form(...),
    msg_llegada: str = Form(...),
    msg_salida: str = Form(...),
    user=Depends(get_current_user)
):
    if not user:
        raise HTTPException(status_code=401)

    conn = get_db()
    conn.execute(
        '''
        UPDATE contacts
        SET contact_name = ?, phone_number = ?, msg_llegada = ?, msg_salida = ?
        WHERE id = ? AND user_id = ?
        ''',
        (name, phone, msg_llegada, msg_salida, contact_id, user["id"])
    )
    conn.commit()
    conn.close()

    return RedirectResponse(url="/", status_code=status.HTTP_303_SEE_OTHER)

@app.get("/contacts/delete/{contact_id}")
async def delete_contact(contact_id: int, user=Depends(get_current_user)):
    if not user: raise HTTPException(status_code=401)
    
    conn = get_db()
    conn.execute("DELETE FROM contacts WHERE id = ? AND user_id = ?", (contact_id, user["id"]))
    conn.commit()
    conn.close()
    return RedirectResponse(url="/", status_code=status.HTTP_303_SEE_OTHER)

# --- API PARA MÓVIL (ENDPOINT REAL) ---

@app.post("/api/v1/events")
async def handle_event(payload: EventPayload, user=Depends(get_current_user)):
    if not user:
        raise HTTPException(status_code=401, detail="Token de API inválido")

    conn = get_db()
    contacts = conn.execute("SELECT * FROM contacts WHERE user_id = ?", (user["id"],)).fetchall()
    
    ahora = datetime.now(ARG_TZ)
    time_str = ahora.strftime("%H:%M")
    
    results = []
    is_manual = payload.event_type == "manual_check"
    
    for c in contacts:
        # Si es manual, usamos el mensaje de llegada como base para la prueba
        actual_event = "llegada" if is_manual else payload.event_type
        template = c["msg_llegada"] if actual_event == "llegada" else c["msg_salida"]
        mensaje = template.replace("{user}", user["full_name"]).replace("{time}", time_str)

        if is_manual:
            # Mensaje más claro para chequeos manuales y evitar confusiones
            mensaje = f"🧪 [CHEQUEO MANUAL — NO ES UN EVENTO REAL]\n{mensaje}"

        sid = send_whatsapp(c["phone_number"], mensaje)

        # Guardar en logs indicando que fue un chequeo manual para diferenciarlo
        log_event_type = "MANUAL_CHECK" if is_manual else payload.event_type
        conn.execute('''
            INSERT INTO notification_logs (user_id, event_type, recipient, status, twilio_sid, timestamp)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (user["id"], log_event_type, c["contact_name"], "sent", sid, ahora.isoformat()))
        results.append({"contact": c["contact_name"], "sid": sid})
    
    conn.commit()
    conn.close()
    
    return {"status": "accepted", "notifications_sent": len(results), "details": results}

# --- SIMULACIÓN (DASHBOARD) ---

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
