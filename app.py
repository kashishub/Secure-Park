import os
import secrets
import psycopg2
import base64
from io import BytesIO
from flask import Flask, render_template, request, redirect, url_for, flash
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user, current_user
from werkzeug.security import generate_password_hash, check_password_hash
import qrcode


app = Flask(__name__)
app.secret_key = os.environ.get("SECRET_KEY", "securepark_secret_key")

login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = "login"


# ==============================
# Database Connection
# ==============================

def get_db_connection():
    return psycopg2.connect(os.environ.get("DATABASE_URL"))


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
# Home
# ==============================

@app.route("/")
def home():
    return redirect(url_for("login"))


# ==============================
# Register
# ==============================

@app.route("/register", methods=["GET", "POST"])
def register_user():
    if request.method == "POST":

        email = request.form.get("email")
        password = request.form.get("password")
        confirm_password = request.form.get("confirm_password")

        if not email or not password or not confirm_password:
            flash("All fields are required.")
            return redirect(url_for("register_user"))

        if password != confirm_password:
            flash("Passwords do not match.")
            return redirect(url_for("register_user"))

        email = email.strip().lower()
        hashed_password = generate_password_hash(password)

        conn = get_db_connection()
        cursor = conn.cursor()

        try:
            cursor.execute(
                "INSERT INTO users (email, password) VALUES (%s, %s)",
                (email, hashed_password)
            )
            conn.commit()
        except psycopg2.Error:
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


# ==============================
# Login
# ==============================

@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":

        email = request.form.get("email")
        password = request.form.get("password")

        if not email or not password:
            flash("All fields are required.")
            return redirect(url_for("login"))

        email = email.strip().lower()

        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute(
            "SELECT id, email, password, role, created_at, is_blocked FROM users WHERE email = %s",
            (email,)
        )
        user = cursor.fetchone()

        cursor.close()
        conn.close()

        if user and check_password_hash(user[2], password):

            user_id, user_email, password_hash, role, created_at, is_blocked = user

            if is_blocked:
                flash("Your account has been suspended.")
                return redirect(url_for("login"))

            login_user(User(user_id, user_email, password_hash, role))

            return redirect(url_for("dashboard"))

        flash("Invalid email or password.")
        return redirect(url_for("login"))

    return render_template("login.html")


# ==============================
# Logout
# ==============================

@app.route("/logout")
@login_required
def logout():
    logout_user()
    return redirect(url_for("login"))


# ==============================
# Delete Account
# ==============================

@app.route("/delete-account", methods=["POST"])
@login_required
def delete_account():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute(
        "DELETE FROM users WHERE id = %s",
        (current_user.id,)
    )
    conn.commit()
    cursor.close()
    conn.close()
    logout_user()
    flash("Your account has been deleted.")
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

        vehicle_list.append({
            "id": vehicle_id,
            "vehicle": vehicle_number,
            "call_number": call_number,
            "token": token
        })

    return render_template("dashboard.html", vehicles=vehicle_list)


# ==============================
# Add Vehicle
# ==============================

@app.route("/add-vehicle", methods=["POST"])
@login_required
def add_vehicle():

    vehicle = request.form.get("vehicle")
    call_number = request.form.get("call_number")
    whatsapp_number = request.form.get("whatsapp_number")

    if not vehicle or not call_number:
        flash("Required fields missing.")
        return redirect(url_for("dashboard"))

    vehicle = vehicle.strip().upper()

    if not whatsapp_number:
        whatsapp_number = call_number

    conn = get_db_connection()
    cursor = conn.cursor()

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


# ==============================
# Sticker Route (FIXED)
# ==============================

@app.route("/sticker/<token>")
@login_required
def sticker(token):

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
        return "Unauthorized or Invalid Token", 403

    vehicle = data[0]

    qr_url = request.host_url + "v/" + token
    qr = qrcode.make(qr_url)

    buffer = BytesIO()
    qr.save(buffer, format="PNG")
    buffer.seek(0)

    qr_base64 = base64.b64encode(buffer.getvalue()).decode()

    return render_template(
        "qr_result.html",
        vehicle=vehicle,
        qr_image=qr_base64
    )


# ==============================
# Contact Route
# ==============================

@app.route("/v/<token>")
def contact(token):

    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT v.vehicle, v.call_number, v.whatsapp_number
        FROM vehicles v
        WHERE v.token = %s
    """, (token,))

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


if __name__ == "__main__":
    app.run(debug=True)