import os
import secrets
import psycopg2
import base64
from io import BytesIO
from flask import Flask, render_template, request, redirect, url_for, flash, send_file
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user, current_user
from werkzeug.security import generate_password_hash, check_password_hash
import qrcode


app = Flask(__name__)
app.secret_key = "securepark_secret_key"

login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = "login"


# ==============================
# Database Connection
# ==============================

def get_db_connection():
    return psycopg2.connect(os.environ.get("DATABASE_URL"))


def init_db():
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            email TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            role TEXT DEFAULT 'owner',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    """)

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS vehicles (
            id SERIAL PRIMARY KEY,
            vehicle TEXT NOT NULL,
            call_number TEXT NOT NULL,
            whatsapp_number TEXT NOT NULL,
            token TEXT UNIQUE NOT NULL,
            user_id INTEGER REFERENCES users(id) ON DELETE CASCADE
        );
    """)

    conn.commit()
    cursor.close()
    conn.close()


init_db()


# ==============================
# User Model
# ==============================

class User(UserMixin):
    def __init__(self, id, email, password, role):
        self.id = id
        self.email = email
        self.password = password
        self.role = role


@login_manager.user_loader
def load_user(user_id):
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute(
        "SELECT id, email, password, role FROM users WHERE id = %s",
        (user_id,)
    )
    user = cursor.fetchone()

    cursor.close()
    conn.close()

    if user:
        return User(*user)
    return None


# ==============================
# Routes
# ==============================

@app.route("/")
def home():
    return redirect(url_for("login"))


@app.route("/register", methods=["GET", "POST"])
def register_user():
    if request.method == "POST":
        email = request.form["email"].strip().lower()
        password = request.form["password"]

        hashed_password = generate_password_hash(password)

        conn = get_db_connection()
        cursor = conn.cursor()

        try:
            cursor.execute(
                "INSERT INTO users (email, password) VALUES (%s, %s)",
                (email, hashed_password)
            )
            conn.commit()
        except:
            conn.rollback()
            flash("Email already registered.")
            cursor.close()
            conn.close()
            return redirect(url_for("register_user"))

        cursor.close()
        conn.close()

        flash("Account created. Please login.")
        return redirect(url_for("login"))

    return render_template("register_user.html")


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        email = request.form["email"].strip().lower()
        password = request.form["password"]

        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute(
            "SELECT id, email, password, role FROM users WHERE email = %s",
            (email,)
        )
        user = cursor.fetchone()

        cursor.close()
        conn.close()

        if user and check_password_hash(user[2], password):
            login_user(User(*user))
            return redirect(url_for("dashboard"))
        else:
            flash("Invalid email or password.")
            return redirect(url_for("login"))

    return render_template("login.html")


@app.route("/logout")
@login_required
def logout():
    logout_user()
    return redirect(url_for("login"))


# ==============================
# Dashboard
# ==============================

@app.route("/dashboard")
@login_required
def dashboard():
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute(
        "SELECT id, vehicle, call_number, token FROM vehicles WHERE user_id = %s",
        (current_user.id,)
    )
    vehicles = cursor.fetchall()

    cursor.close()
    conn.close()

    vehicle_list = []

    for v in vehicles:
        vehicle_id, vehicle_number, call_number, token = v

        qr_url = request.host_url + "v/" + token
        qr = qrcode.make(qr_url)

        buffer = BytesIO()
        qr.save(buffer, format="PNG")
        buffer.seek(0)

        qr_base64 = base64.b64encode(buffer.getvalue()).decode()

        vehicle_list.append({
            "id": vehicle_id,
            "vehicle": vehicle_number,
            "call_number": call_number,
            "qr_image": qr_base64,
            "token": token
        })

    return render_template("dashboard.html", vehicles=vehicle_list)


# ==============================
# Add Vehicle
# ==============================

@app.route("/add-vehicle", methods=["POST"])
@login_required
def add_vehicle():
    vehicle = request.form["vehicle"].strip().upper()
    call_number = request.form["call_number"].strip()
    whatsapp_number = request.form["whatsapp_number"].strip()

    if whatsapp_number == "":
        whatsapp_number = call_number

    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute(
        "SELECT COUNT(*) FROM vehicles WHERE user_id = %s",
        (current_user.id,)
    )
    count = cursor.fetchone()[0]

    if count >= 3:
        flash("Maximum 3 vehicles allowed per account.")
        cursor.close()
        conn.close()
        return redirect(url_for("dashboard"))

    cursor.execute(
        "SELECT id FROM vehicles WHERE vehicle = %s",
        (vehicle,)
    )
    if cursor.fetchone():
        flash("Vehicle already registered.")
        cursor.close()
        conn.close()
        return redirect(url_for("dashboard"))

    token = secrets.token_urlsafe(6)

    cursor.execute(
        """
        INSERT INTO vehicles (vehicle, call_number, whatsapp_number, token, user_id)
        VALUES (%s, %s, %s, %s, %s)
        """,
        (vehicle, call_number, whatsapp_number, token, current_user.id)
    )

    conn.commit()
    cursor.close()
    conn.close()

    flash("Vehicle added successfully.")
    return redirect(url_for("dashboard"))


@app.route("/delete/<int:vehicle_id>")
@login_required
def delete_vehicle(vehicle_id):
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute(
        "DELETE FROM vehicles WHERE id = %s AND user_id = %s",
        (vehicle_id, current_user.id)
    )

    conn.commit()
    cursor.close()
    conn.close()

    flash("Vehicle deleted.")
    return redirect(url_for("dashboard"))


# ==============================
# Contact Route
# ==============================

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

    return render_template(
        "contact.html",
        vehicle=vehicle,
        call_number=call_number,
        whatsapp_number=whatsapp_number
    )


# ==============================
# Download QR Route
# ==============================

from PIL import Image, ImageDraw, ImageFont

@app.route("/download-qr/<token>")
@login_required
def download_qr(token):

    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute(
        "SELECT vehicle FROM vehicles WHERE token = %s AND user_id = %s",
        (token, current_user.id)
    )
    data = cursor.fetchone()

    cursor.close()
    conn.close()

    if not data:
        return "Unauthorized", 403

    vehicle = data[0]

    SIZE = 700
    sticker = Image.new("RGB", (SIZE, SIZE), "#f5f5f5")
    draw = ImageDraw.Draw(sticker)

    # Rounded border
    draw.rounded_rectangle(
        [20, 20, SIZE-20, SIZE-20],
        radius=40,
        outline="black",
        width=5
    )

    # Watermark
    for y in range(0, SIZE, 150):
        draw.text((0, y), "SECURE PARK  •  " * 5, fill=(180,180,180))

    # Fonts
    try:
        title_font = ImageFont.truetype("arial.ttf", 40)
        small_font = ImageFont.truetype("arial.ttf", 24)
    except:
        title_font = ImageFont.load_default()
        small_font = ImageFont.load_default()

    # Title
    title = "Vehicle Contact System"
    w, h = draw.textbbox((0,0), title, font=title_font)[2:]
    draw.text(((SIZE-w)/2, 60), title, fill="black", font=title_font)

    # Vehicle number
    vehicle_text = f"Vehicle: {vehicle}"
    w, h = draw.textbbox((0,0), vehicle_text, font=title_font)[2:]
    draw.text(((SIZE-w)/2, 120), vehicle_text, fill="black", font=title_font)

    subtitle = "Scan to contact vehicle owner"
    w, h = draw.textbbox((0,0), subtitle, font=small_font)[2:]
    draw.text(((SIZE-w)/2, 170), subtitle, fill="gray", font=small_font)

    # QR
    qr_url = request.host_url + "v/" + token
    qr = qrcode.make(qr_url).convert("RGB")
    qr = qr.resize((350, 350))

    qr_x = (SIZE-350)//2
    qr_y = 230
    sticker.paste(qr, (qr_x, qr_y))

    # Footer
    footer = "In case of emergency or blocking,\nplease scan this QR."
    w, h = draw.multiline_textbbox((0,0), footer, font=small_font)[2:]
    draw.multiline_text(
        ((SIZE-w)/2, 610),
        footer,
        fill="black",
        font=small_font,
        align="center"
    )

    buffer = BytesIO()
    sticker.save(buffer, format="PNG")
    buffer.seek(0)

    return send_file(
        buffer,
        mimetype="image/png",
        as_attachment=True,
        download_name=f"{vehicle}_Sticker.png"
    )


# ==============================
# Run App
# ==============================

if __name__ == "__main__":
    app.run(debug=True)