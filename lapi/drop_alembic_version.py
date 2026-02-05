import sqlite3

conn = sqlite3.connect("lapi.db")  # adapte le chemin vers ta base SQLite
cursor = conn.cursor()

# Vérifie les tables existantes
cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
print("Tables avant suppression:", cursor.fetchall())

# Supprime la table alembic_version
cursor.execute("DROP TABLE IF EXISTS alembic_version;")

conn.commit()

# Vérifie après suppression
cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
print("Tables après suppression:", cursor.fetchall())

conn.close()