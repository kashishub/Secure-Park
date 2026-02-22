import os
import secrets
import psycopg2
import base64
from io import BytesIO
from flask import Flask, render_template, request, redirect, url_for, flash
import qrcode

app = Flask(__name__)
app.secret_key = "securepark_secret_key"


# ==============================
# Database Connection
# ==============================

def get_db_connection():
    conn = psycopg2.connect(os.environ.get("DATABASE_URL"))
    return conn


def init_db():
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS vehicles (
            id SERIAL PRIMARY KEY,
            vehicle TEXT NOT NULL,
            call_number TEXT NOT NULL,
            whatsapp_number TEXT NOT NULL,
            token TEXT UNIQUE NOT NULL
        );
    """)

    conn.commit()
    cursor.close()
    conn.close()


init_db()


# ==============================
# Routes
# ==============================

@app.route("/")
def home():
    return render_template("register.html")


@app.route("/generate", methods=["POST"])
def generate():

    vehicle = request.form["vehicle"].strip().upper()
    call_number = request.form["call_number"].strip()
    whatsapp_number = request.form["whatsapp_number"].strip()

    if whatsapp_number == "":
        whatsapp_number = call_number

    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute(
        "SELECT call_number FROM vehicles WHERE vehicle = %s",
        (vehicle,)
    )
    existing = cursor.fetchone()

    if existing:
        existing_call = existing[0]

        cursor.close()
        conn.close()

        if existing_call == call_number:
            flash("Vehicle already registered.")
        else:
            flash("Vehicle already registered with a different number.")

        return redirect(url_for("home"))

    token = secrets.token_urlsafe(6)

    cursor.execute(
        """
        INSERT INTO vehicles (vehicle, call_number, whatsapp_number, token)
        VALUES (%s, %s, %s, %s)
        """,
        (vehicle, call_number, whatsapp_number, token)
    )

    conn.commit()
    cursor.close()
    conn.close()

    # ==========================
    # Generate QR (IN MEMORY)
    # ==========================

    qr_url = request.host_url + "v/" + token

    qr = qrcode.make(qr_url)

    buffer = BytesIO()
    qr.save(buffer, format="PNG")
    buffer.seek(0)

    qr_base64 = base64.b64encode(buffer.getvalue()).decode()

    return render_template("qr_result.html",
                           vehicle=vehicle,
                           token=token,
                           qr_image=qr_base64)


@app.route("/v/<token>")
def contact(token):

    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute(
        "SELECT vehicle, call_number, whatsapp_number FROM vehicles WHERE token = %s",
        (token,)
    )
    data = cursor.fetchone()

    cursor.close()
    conn.close()

    if not data:
        return "Invalid or expired QR code."

    vehicle, call_number, whatsapp_number = data

    return render_template("contact.html",
                           vehicle=vehicle,
                           call_number=call_number,
                           whatsapp_number=whatsapp_number)


# ==============================
# Run App
# ==============================

if __name__ == "__main__":
    app.run(debug=True)