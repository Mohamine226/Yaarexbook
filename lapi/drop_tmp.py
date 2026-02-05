import sqlite3

conn = sqlite3.connect("lapi.db")  # ou users.db si c'est ta base
cursor = conn.cursor()

# Vérifie les tables existantes
cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
print("Tables avant suppression:", cursor.fetchall())

# Supprime la table temporaire
cursor.execute("DROP TABLE IF EXISTS _alembic_tmp_documents;")

conn.commit()

# Vérifie après suppression
cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
print("Tables après suppression:", cursor.fetchall())

conn.close()