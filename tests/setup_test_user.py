import sqlite3

DB = 'mama_notifier.db'
conn = sqlite3.connect(DB)
cur = conn.cursor()

user_id = 'testuser1'
api_token = 'mama_testtoken1234'

# Insert user if not exists
try:
    cur.execute("INSERT INTO users (id, full_name, email, password_hash, api_token) VALUES (?, ?, ?, ?, ?)",
                (user_id, 'Tester', 'test@example.com', 'dummyhash', api_token))
    print('User inserted')
except Exception as e:
    print('User insert skipped or error:', e)

# Insert contact if not exists
try:
    cur.execute("INSERT INTO contacts (user_id, contact_name, phone_number, msg_llegada, msg_salida) VALUES (?, ?, ?, ?, ?)",
                (user_id, 'Contacto Test', 'whatsapp:+00000000000', '¡Hola! {user} llegó a su destino. ✅', '¡Hola! {user} se desconectó. 📵'))
    print('Contact inserted')
except Exception as e:
    print('Contact insert skipped or error:', e)

conn.commit()
print('api_token=' + api_token)
conn.close()
