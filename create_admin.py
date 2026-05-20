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
    
    # Check if admin@email.com already exists
    cur.execute("SELECT id FROM users WHERE email = 'admin@email.com'")
    row = cur.fetchone()
    if row:
        print("Admin user already exists! ID:", row[0])
    else:
        # Create user via stored procedure
        cur.execute(
            "SELECT * FROM create_user(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
            ('Sarah', 'Connor', '1990-01-01', '1234567890', 'admin@email.com', 'Female', '123 Main St', 1, '95101', 1, 'password123')
        )
        new_user = cur.fetchone()
        conn.commit()
        print("Admin user created successfully:", new_user)
        
    conn.close()
except Exception as e:
    print("Error:", e)
