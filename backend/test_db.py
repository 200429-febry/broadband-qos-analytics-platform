from database import engine

try:
    conn = engine.connect()
    print("DATABASE CONNECTED SUCCESSFULLY")
    conn.close()

except Exception as e:
    print("ERROR:", e)