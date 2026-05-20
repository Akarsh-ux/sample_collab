import os
import psycopg2
from dotenv import load_dotenv

load_dotenv()

passwords = ["Optirise@1234", "admin123", "password123", "pass123", "tanvi123", "mike123", "jane123", "vol123", "coord123", "opto123"]
emails = ["tanvi@email.com", "jane.johnson@email.com", "mike@email.com", "iamrashdan@gmail.com"]

try:
    conn = psycopg2.connect(
        host=os.getenv("DB_HOST"),
        port=os.getenv("DB_PORT"),
        dbname=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD")
    )
    cur = conn.cursor()
    for email in emails:
        for pwd in passwords:
            cur.execute(
                "SELECT id FROM users WHERE email = %s AND password_hash = crypt(%s, password_hash)",
                (email, pwd)
            )
            row = cur.fetchone()
            if row:
                print(f"MATCH FOUND: {email} -> {pwd}")
    conn.close()
except Exception as e:
    print("Error:", e)
