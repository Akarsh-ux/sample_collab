import os
import psycopg2
from dotenv import load_dotenv

load_dotenv()

try:
    conn = psycopg2.connect(
        host=os.getenv("DB_HOST"),
        port=os.getenv("DB_PORT"),
        dbname=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD")
    )
    cur = conn.cursor()
    cur.execute("SELECT id, first_name, last_name, email, role_id, password_hash FROM users")
    rows = cur.fetchall()
    print("USERS IN DATABASE:")
    for r in rows:
        print(f"ID: {r[0]} | Name: {r[1]} {r[2]} | Email: {r[3]} | RoleID: {r[4]} | PasswordHash: {r[5]}")
    conn.close()
except Exception as e:
    print("Error:", e)
