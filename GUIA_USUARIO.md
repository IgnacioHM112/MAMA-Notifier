# 📖 Guía rápida de Mama‑Notifier (para usuarios)

> **Mama‑Notifier** es una app que avisa a tus familiares cuando llegas o sales de un lugar (casa, trabajo, escuela) sin que tengas que escribir nada.

---

## 1. Qué necesitas antes de empezar
- Un teléfono **Android** (la app está en formato APK).
- Una cuenta de **Telegram** (gratis).
- Saber el **nombre exacto** de tu Wi‑Fi de casa (ej. `MiCasa_2.4G`).

---

## 2. Crear tu cuenta
1. Abre el enlace que te mandó el administrador (algo como `https://mama-notifier-production.up.railway.app`).
2. Pulsa **Registro**, pon tu nombre, email y una contraseña.
3. Ya estás dentro del panel web.

---

## 3. Añadir contactos que recibirán los avisos
1. En el panel, ve a **Configurar Contactos y Mensajes**.
3. Pide a cada familiar que abra Telegram y escriba a **`@userinfobot`** y pulse **Iniciar**.
   - El bot le responderá con un número, ej. `Id: 123456789`. Ese es su **Chat ID**.
3. En el formulario pon:
   - **Nombre**: como quieras que aparezca (ej. “Mamá”).
   - **Chat ID de Telegram**: el número que te dio el bot.
   - **Mensaje al LLEGAR** y **Mensaje al SALIR** (puedes dejar los de ejemplo).
4. Pulsa **+ Vincular Contacto y Enviar Invitación 🔔**.
   - El familiar recibirá un mensaje de bienvenida en Telegram.

---

## 4. Instalar la app en tu móvil
1. Descarga el archivo `app-release.apk` que te pasó el administrador (Google Drive, cable USB, etc.).
2. En el móvil abre **Archivos / Descargas**, toca el APK y dale a **Instalar**.
   - Si te pide permiso “Instalar apps desconocidas”, actívalo para la app que usas (Files, Chrome, Drive…).
3. Abre la app **Mama‑Notifier** e inicia sesión con el mismo email y contraseña que usaste en la web.

---

## 5. Activar el “Modo Guardián”
1. En la pestaña **Monitor** escribe exactamente el **nombre de tu Wi‑Fi seguro** (respeta mayúsculas/minúsculas).
2. En **Nombre de este lugar** pon “Casa” (o “Trabajo”).
3. Pulsa **Activar Modo Guardián** y concede los permisos que te pida (ubicación, notificaciones, acceso a Wi‑Fi).
4. Verás una notificación fija “Modo Guardián Activo”. **No la deslices**; mientras esté ahí la app vigila tu Wi‑Fi.

---

## 6. Prueba que todo funciona
- Conéctate al Wi‑Fi configurado → en segundos deberías recibir en Telegram el mensaje de **llegada**.
- Desconéctate (modo avión o apaga Wi‑Fi) → recibirás el mensaje de **salida**.
- También puedes pulsar **Verificar ahora (Manual)** en la app para forzar un envío de prueba.

---

## 7. Consejos para que no falte ningún aviso
- **Batería**: en Ajustes → Apps → Mama‑Notifier → Batería → elige **Sin restricciones / No optimizar**.
- **Ubicación**: Android 12+ pide permiso de ubicación “Mientras se usa la app” o “Siempre” para poder leer el Wi‑Fi.
- **Notificación fija**: mantén la notificación “Modo Guardián Activo” visible; si la borras el sistema puede parar la vigilancia.

---

## 8. Preguntas frecuentes
| Pregunta | Respuesta corta |
|---|---|
| ¿Funciona sin internet? | No, necesita conexión para mandar el Telegram. |
| ¿Gasta mucha batería? | Muy poco; solo escucha cambios de Wi‑Fi. |
| ¿Puedo añadir varios lugares? | Sí, cambia el SSID en la app cuando estés en otro sitio (trabajo, casa de un familiar). |
| ¿Los contactos ven mi ubicación exacta? | No, solo reciben el mensaje que tú redactaste (ej. “Llegué a casa”). |

---

## 9. Soporte
Si algo no funciona, avísale a la persona que te configuró la app. Puede revisar los logs en el panel web (sección **Actividad Reciente**) y reenviar la invitación si hace falta.

---

**¡Listo!** A partir de ahora tu familia sabrá cuándo llegas y sales sin que tengas que escribir ni una sola vez. 🎉