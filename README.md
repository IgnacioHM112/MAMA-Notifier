# 🚀 MAMA-Notifier (Telegram)

Sistema de notificaciones automático que avisa a contactos por **Telegram** cuando una persona llega o sale de zonas seguras (casa, trabajo, escuela). Backend SaaS multi-usuario + App móvil Flutter con monitoreo Wi-Fi en background.

## ✨ Características
- **Notificaciones instantáneas por Telegram** (gratis, sin sandbox, sin plantillas)
- **Multi-usuario SaaS**: Auth JWT, cada usuario gestiona sus contactos y mensajes
- **Monitoreo Wi-Fi automático** en Android/iOS (Foreground Service + WorkManager)
- **Dashboard web** para gestionar contactos, simular eventos y ver historial
- **Persistencia SQLite**: usuarios, contactos (chat_id), logs de notificaciones
- **Zona horaria Argentina (UTC-3)** forzada en todo el sistema
- **Dockerizado** para deploy sencillo en VPS/Railway/Render/Fly.io

## 🛠️ Stack Tecnológico
- **Backend**: FastAPI, Uvicorn, SQLite, JWT (HS256), bcrypt, python-telegram-bot
- **Dashboard**: Jinja2 + TailwindCSS (via CDN)
- **App Móvil**: Flutter, `flutter_foreground_task`, `workmanager`, `connectivity_plus`, `flutter_secure_storage`
- **Deploy**: Docker + Docker Compose

---

## 🚀 Configuración e Instalación

### 1. Requisitos Previos
- Docker y Docker Compose
- Bot de Telegram (crear con **@BotFather** → `/newbot`)
- Chat ID de cada contacto (escribir a **@userinfobot** en Telegram)

### 2. Variables de Entorno
Crea `.env` basado en `.env.example`:
```env
TELEGRAM_BOT_TOKEN=123456789:ABCdefGhIJKlmNoPQRsTUVwxyZ
JWT_SECRET_KEY=clave_super_secreta_de_64_caracteres_minimo_cambiala_en_produccion
```

### 3. Despliegue con Docker
```bash
docker-compose up --build -d
```
La API queda en `http://localhost:5000`

### 4. Uso
1. Abre `http://localhost:5000` → Regístrate / Inicia sesión
2. En **Configurar Contactos** añade nombre + **Chat ID de Telegram** + mensajes personalizados
3. En la **App Flutter**: Login → Configura SSID de tu Wi-Fi seguro → Activa "Modo Guardián"
4. Al conectar/desconectar del Wi-Fi configurado → se envía notificación a Telegram

---

## 📱 Obtener Chat ID de Telegram
1. Abre Telegram y busca **@userinfobot**
2. Envía `/start`
3. Te responderá con tu `Id: 123456789` (ese es el `chat_id`)
4. Úsalo al agregar contactos en el dashboard o la app

---

## 📝 Estructura de la Base de Datos
- `users`: id, full_name, email, password_hash, api_token
- `contacts`: id, user_id, contact_name, **chat_id**, msg_llegada, msg_salida
- `notification_logs`: id, user_id, event_type, recipient, status, telegram_message_id, timestamp

---

## 🇦🇷 Zona Horaria
El sistema fuerza `America/Argentina/Buenos_Aires` para timestamps en mensajes y BD.

---

## 🔐 Autenticación App Móvil (JWT / Bearer)
- `POST /api/v1/login` → `{ "access_token": "...", "token_type": "bearer" }`
- Guardar token en `flutter_secure_storage`
- `POST /api/v1/events` con header `Authorization: Bearer <token>`

---

## 🌐 Deploy en Producción (No Vercel)
**Vercel NO sirve**: es serverless (sin procesos largos, sin FS persistente, sin background workers).

**Opciones recomendadas (~$5-7/mes):**
- **Railway** / **Render** / **Fly.io** (Docker nativo, fácil)
- **VPS** (DigitalOcean, Hetzner, Contabo) + Docker Compose + Nginx + Certbot (HTTPS)

Checklist producción:
- [ ] `JWT_SECRET_KEY` única y aleatoria (64+ chars)
- [ ] HTTPS/TLS (Certbot/Let's Encrypt)
- [ ] `TELEGRAM_BOT_TOKEN` de bot de producción
- [ ] Compilar APK/IPA: `flutter build apk --release` / `flutter build ios --release`

---

## 📋 Estructura del Proyecto
```
MAMA-Notifier/
├── main.py                 # FastAPI backend (Telegram)
├── requirements.txt        # Python deps
├── Dockerfile / docker-compose.yml
├── .env.example
├── templates/              # login.html, dashboard.html, contact_edit.html
├── flutter/
│   ├── pubspec.yaml
│   └── lib/
│       ├── main.dart       # App completa (GUI + Guardián)
│       ├── api_service.dart
│       ├── wifi_monitor.dart
│       └── event_model.dart
└── docs: README.md, PRESENTACION.md, ESTADO_FINAL.md
```

---

## 🎯 Estado Actual
- ✅ Backend FastAPI + JWT + Telegram Bot API
- ✅ Dashboard web completo
- ✅ App Flutter con Modo Guardián (background Wi-Fi monitoring)
- ✅ Docker listo para deploy
- ⚠️ Pendiente: HTTPS, compilar builds móviles, deploy en cloud

---

Desarrollado para mantener a la familia comunicada sin complicaciones.