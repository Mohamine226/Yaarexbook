import sqlite3

# Ouvre ta base SQLite (remplace par users.db si c'est ta base)
conn = sqlite3.connect("lapi.db")
cursor = conn.cursor()

# Supprime la table temporaire si elle existe
cursor.execute("DROP TABLE IF EXISTS _alembic_tmp_documents;")

conn.commit()
conn.close()

print("✅ Table _alembic_tmp_documents supprimée")