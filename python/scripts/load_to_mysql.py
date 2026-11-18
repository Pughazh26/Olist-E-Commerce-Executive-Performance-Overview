import os
import csv
import pymysql
from dotenv import load_dotenv

load_dotenv()

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_USER = os.getenv("DB_USER", "root")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_NAME = os.getenv("DB_NAME", "olist_db")

conn = pymysql.connect(
    host=DB_HOST,
    port=DB_PORT,
    user=DB_USER,
    password=DB_PASSWORD,
    database=DB_NAME,
    charset="utf8mb4",
    autocommit=False
)

try:
    with conn.cursor() as cursor:
        # 1. Execute Schema SQL file
        schema_path = os.path.join("sql", "01_schema", "create_tables.sql")
        print("1. Creating tables from create_tables.sql...")
        with open(schema_path, "r", encoding="utf-8") as f:
            sql_script = f.read()

        for statement in sql_script.split(";"):
            stmt = statement.strip()
            if stmt:
                cursor.execute(stmt)
        conn.commit()
        print("   -> All 9 tables created successfully with PKs and FKs!\n")

        # 2. Load Cleaned CSVs in Parent-to-Child Order
        load_order = [
            ("geolocation", "geolocation_cleaned.csv"),
            ("customers", "customers_cleaned.csv"),
            ("sellers", "sellers_cleaned.csv"),
            ("category_translation", "category_translation_cleaned.csv"),
            ("products", "products_cleaned.csv"),
            ("orders", "orders_cleaned.csv"),
            ("order_items", "order_items_cleaned.csv"),
            ("order_payments", "order_payments_cleaned.csv"),
            ("order_reviews", "order_reviews_cleaned.csv"),
        ]

        cleaned_dir = os.path.join("data", "cleaned")
        print("2. Loading cleaned CSVs into MySQL (olist_db)...")

        for table_name, csv_file in load_order:
            file_path = os.path.join(cleaned_dir, csv_file)
            with open(file_path, "r", encoding="utf-8", newline="") as f:
                reader = csv.reader(f)
                headers = next(reader)
                cols = ", ".join(headers)
                placeholders = ", ".join(["%s"] * len(headers))
                insert_sql = f"INSERT INTO {table_name} ({cols}) VALUES ({placeholders})"

                batch = []
                total_rows = 0
                for row in reader:
                    # Convert empty strings to None (SQL NULL)
                    clean_row = [None if val == "" else val for val in row]
                    batch.append(clean_row)
                    if len(batch) == 5000:
                        cursor.executemany(insert_sql, batch)
                        total_rows += len(batch)
                        batch.clear()

                if batch:
                    cursor.executemany(insert_sql, batch)
                    total_rows += len(batch)

            conn.commit()
            print(f"   -> Loaded {table_name:22s}: {total_rows:6d} rows")

        # 3. Verify Row Counts Directly from MySQL
        print("\n3. Verifying row counts inside MySQL:")
        for table_name, _ in load_order:
            cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
            count = cursor.fetchone()[0]
            print(f"   -> MySQL {table_name:22s}: {count:6d} rows")

    print("\nPHASE 4 COMPLETE: All data successfully loaded and verified!")

finally:
    conn.close()