from flask import Flask, render_template, request, redirect
import sqlite3
import secrets
import qrcode
import os

app = Flask(__name__)

# -------------------------------
# Create database & table if not exists
# -------------------------------
def init_db():
    conn = sqlite3.connect("database.db")
    cursor = conn.cursor()

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS vehicles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            vehicle TEXT NOT NULL,
            call_number TEXT NOT NULL,
            whatsapp_number TEXT NOT NULL,
            token TEXT NOT NULL
        )
    """)

    conn.commit()
    conn.close()

init_db()

# -------------------------------
# Registration Page
# -------------------------------
@app.route("/")
def home():
    return render_template("register.html")


# -------------------------------
# Generate QR
# -------------------------------
@app.route("/generate", methods=["POST"])
def generate():

    # ✅ Step 1: Normalize input
    vehicle = request.form["vehicle"].strip().upper()
    call_number = request.form["call_number"].strip()
    whatsapp_number = request.form["whatsapp_number"].strip()

    # If WhatsApp empty → use call number
    if whatsapp_number == "":
        whatsapp_number = call_number

    # ✅ Step 2: Phone validation
    if not call_number.isdigit() or len(call_number) != 10:
        return render_template(
            "register.html",
            message="Enter a valid 10-digit phone number."
        )

    token = secrets.token_urlsafe(6)

    conn = sqlite3.connect("database.db")
    cursor = conn.cursor()

    # ✅ Step 3: Duplicate logic
    cursor.execute("""
        SELECT call_number FROM vehicles WHERE vehicle = ?
    """, (vehicle,))
    existing = cursor.fetchone()

    if existing:
        existing_number = existing[0]

        # Case 1: Same vehicle + same number
        if existing_number == call_number:
            conn.close()
            return render_template(
                "register.html",
                message="Vehicle already registered."
            )

        # Case 2: Vehicle exists but number different
        else:
            conn.close()
            return render_template(
                "register.html",
                message="Vehicle already registered with a different number."
            )

    # Case 3: Vehicle does not exist → Insert
    cursor.execute("""
        INSERT INTO vehicles (vehicle, call_number, whatsapp_number, token)
        VALUES (?, ?, ?, ?)
    """, (vehicle, call_number, whatsapp_number, token))

    conn.commit()
    conn.close()

    # ✅ Step 4: Generate QR
    qr_url = request.host_url + "v/" + token
    qr = qrcode.make(qr_url)

    # Create folder if not exists
    if not os.path.exists("static/qrcodes"):
        os.makedirs("static/qrcodes")

    qr_path = f"static/qrcodes/{token}.png"
    qr.save(qr_path)

    return render_template(
        "qr_result.html",
        vehicle=vehicle,
        token=token,
        qr_image=f"/static/qrcodes/{token}.png"
    )


# -------------------------------
# Contact Page (Public)
# -------------------------------
@app.route("/v/<token>")
def contact(token):

    conn = sqlite3.connect("database.db")
    cursor = conn.cursor()

    cursor.execute("""
        SELECT vehicle, call_number, whatsapp_number
        FROM vehicles
        WHERE token = ?
    """, (token,))
    data = cursor.fetchone()

    conn.close()

    if not data:
        return "Invalid link"

    return render_template(
        "contact.html",
        vehicle=data[0],
        call_number=data[1],
        whatsapp_number=data[2]
    )


# -------------------------------
# Run App
# -------------------------------
if __name__ == "__main__":
    app.run(debug=True)