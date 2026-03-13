import os
import secrets
import json
import base64
from datetime import datetime, timezone
from io import BytesIO

import requests
import firebase_admin
from firebase_admin import credentials, firestore, auth
from flask import Flask, render_template, request, redirect, url_for, flash
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user, current_user
import qrcode


app = Flask(__name__)
app.secret_key = os.environ.get("SECRET_KEY", "securepark_secret_key")

login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = "login"


# ==============================
# Firebase Initialization
# ==============================

def init_firebase_app():
    if firebase_admin._apps:
        return

    credentials_json = os.environ.get("FIREBASE_CREDENTIALS_JSON")
    credentials_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")

    if credentials_json:
        cert = credentials.Certificate(json.loads(credentials_json))
        firebase_admin.initialize_app(cert)
        return

    if credentials_path:
        cert = credentials.Certificate(credentials_path)
        firebase_admin.initialize_app(cert)
        return

    firebase_admin.initialize_app()


init_firebase_app()
db = firestore.client()


def firebase_sign_in(email, password):
    api_key = os.environ.get("FIREBASE_WEB_API_KEY")
    if not api_key:
        raise RuntimeError("FIREBASE_WEB_API_KEY is not configured")

    endpoint = (
        "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword"
        f"?key={api_key}"
    )

    response = requests.post(
        endpoint,
        json={
            "email": email,
            "password": password,
            "returnSecureToken": True,
        },
        timeout=15,
    )

    if response.status_code != 200:
        return None

    return response.json()


def format_timestamp(value):
    if isinstance(value, datetime):
        if value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    return "-"


def is_user_blocked(user_data):
    return bool(user_data.get("isBlocked") or user_data.get("is_blocked"))


def generate_unique_token():
    while True:
        token = secrets.token_urlsafe(6)
        token_query = db.collection("vehicles").where("token", "==", token).limit(1).stream()
        if next(token_query, None) is None:
            return token


# ==============================
# User Model
# ==============================

class User(UserMixin):
    def __init__(self, id, email, role, is_blocked=False):
        self.id = id
        self.email = email
        self.role = role
        self.is_blocked = is_blocked


@login_manager.user_loader
def load_user(user_id):
    user_doc = db.collection("users").document(str(user_id)).get()
    if user_doc.exists:
        data = user_doc.to_dict() or {}
        return User(
            id=str(user_doc.id),
            email=data.get("email", ""),
            role=data.get("role", "owner"),
            is_blocked=is_user_blocked(data),
        )
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

        try:
            existing_user = auth.get_user_by_email(email)
            if existing_user:
                flash("Email already registered.")
                return redirect(url_for("register_user"))
        except auth.UserNotFoundError:
            pass

        try:
            created_user = auth.create_user(
                email=email,
                password=password,
            )

            db.collection("users").document(created_user.uid).set(
                {
                    "uid": created_user.uid,
                    "name": email.split("@")[0],
                    "email": email,
                    "phone": "",
                    "role": "owner",
                    "isBlocked": False,
                    "createdAt": firestore.SERVER_TIMESTAMP,
                }
            )
        except Exception:
            flash("Email already registered.")
            return redirect(url_for("register_user"))

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

        sign_in_data = firebase_sign_in(email, password)
        if sign_in_data:
            user_id = sign_in_data.get("localId")
            user_doc = db.collection("users").document(user_id).get()

            if not user_doc.exists:
                firebase_user = auth.get_user(user_id)
                db.collection("users").document(user_id).set(
                    {
                        "uid": user_id,
                        "name": firebase_user.display_name or email.split("@")[0],
                        "email": firebase_user.email or email,
                        "phone": firebase_user.phone_number or "",
                        "role": "owner",
                        "isBlocked": False,
                        "createdAt": firestore.SERVER_TIMESTAMP,
                    },
                    merge=True,
                )
                user_data = {
                    "email": email,
                    "role": "owner",
                    "isBlocked": False,
                }
            else:
                user_data = user_doc.to_dict() or {}

            if is_user_blocked(user_data):
                flash("Your account has been suspended.")
                return redirect(url_for("login"))

            role = user_data.get("role", "owner")
            login_user(
                User(
                    id=user_id,
                    email=user_data.get("email", email),
                    role=role,
                    is_blocked=False,
                )
            )

            if role == "admin":
                return redirect(url_for("admin_dashboard"))
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
    user_id = str(current_user.id)

    vehicle_docs = db.collection("vehicles").where("userId", "==", user_id).stream()
    for doc in vehicle_docs:
        doc.reference.delete()

    db.collection("users").document(user_id).delete()

    try:
        auth.delete_user(user_id)
    except Exception:
        pass

    logout_user()
    flash("Your account has been deleted.")
    return redirect(url_for("login"))


# ==============================
# Dashboard
# ==============================

@app.route("/dashboard")
@login_required
def dashboard():
    user_id = str(current_user.id)
    vehicles = db.collection("vehicles").where("userId", "==", user_id).stream()

    vehicle_list = []

    for v in vehicles:
        data = v.to_dict() or {}

        vehicle_list.append({
            "id": v.id,
            "vehicle": data.get("vehicleNumber", ""),
            "call_number": data.get("callNumber", ""),
            "token": data.get("token", ""),
            "created_at": data.get("createdAt"),
        })

    vehicle_list.sort(
        key=lambda item: item.get("created_at") or datetime.min.replace(tzinfo=timezone.utc),
        reverse=True,
    )

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

    token = generate_unique_token()

    db.collection("vehicles").add(
        {
            "userId": str(current_user.id),
            "vehicleNumber": vehicle,
            "callNumber": call_number,
            "whatsappNumber": whatsapp_number,
            "token": token,
            "createdAt": firestore.SERVER_TIMESTAMP,
        }
    )

    flash("Vehicle added successfully.")
    return redirect(url_for("dashboard"))

# ==============================
# Delete Vehicle
# ==============================

@app.route("/delete/<vehicle_id>")
@login_required
def delete_vehicle(vehicle_id):
    vehicle_ref = db.collection("vehicles").document(vehicle_id)
    vehicle_doc = vehicle_ref.get()

    if vehicle_doc.exists:
        data = vehicle_doc.to_dict() or {}
        if data.get("userId") == str(current_user.id):
            vehicle_ref.delete()

    flash("Vehicle deleted.")
    return redirect(url_for("dashboard"))

# ==============================
# Sticker Route (FIXED)
# ==============================

@app.route("/sticker/<token>")
@login_required
def sticker(token):
    vehicle_docs = db.collection("vehicles") \
        .where("token", "==", token) \
        .where("userId", "==", str(current_user.id)) \
        .limit(1) \
        .stream()

    vehicle_doc = next(vehicle_docs, None)

    if not vehicle_doc:
        return "Unauthorized or Invalid Token", 403

    vehicle_data = vehicle_doc.to_dict() or {}
    vehicle = vehicle_data.get("vehicleNumber", "")

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
    vehicle_docs = db.collection("vehicles").where("token", "==", token).limit(1).stream()
    vehicle_doc = next(vehicle_docs, None)

    if not vehicle_doc:
        return "Invalid or expired QR code."

    data = vehicle_doc.to_dict() or {}
    vehicle = data.get("vehicleNumber", "")
    call_number = data.get("callNumber", "")
    whatsapp_number = data.get("whatsappNumber") or call_number

    return render_template(
        "contact.html",
        vehicle=vehicle,
        call_number=call_number,
        whatsapp_number=whatsapp_number
    )

# ==============================
# Admin Route
# ==============================

@app.route("/admin")
@login_required
def admin_dashboard():

    # Only admin allowed
    if current_user.role != "admin":
        return redirect(url_for("dashboard"))

    search = request.args.get("search", "")
    role_filter = request.args.get("role", "all")
    status_filter = request.args.get("status", "all")
    page = int(request.args.get("page", 1))

    per_page = 5
    offset = (page - 1) * per_page

    all_user_docs = list(db.collection("users").stream())
    all_vehicle_docs = list(db.collection("vehicles").stream())

    vehicle_count_by_user = {}
    for vehicle_doc in all_vehicle_docs:
        vehicle_data = vehicle_doc.to_dict() or {}
        owner_id = vehicle_data.get("userId")
        if owner_id:
            vehicle_count_by_user[owner_id] = vehicle_count_by_user.get(owner_id, 0) + 1

    filtered_users = []
    for user_doc in all_user_docs:
        user_data = user_doc.to_dict() or {}

        email = (user_data.get("email") or "").strip().lower()
        role = user_data.get("role", "owner")
        blocked = is_user_blocked(user_data)

        if search and search.lower() not in email:
            continue

        if role_filter != "all" and role != role_filter:
            continue

        if status_filter == "active" and blocked:
            continue
        if status_filter == "blocked" and not blocked:
            continue

        filtered_users.append(
            (
                user_doc.id,
                email,
                role,
                blocked,
                format_timestamp(user_data.get("createdAt")),
                vehicle_count_by_user.get(user_doc.id, 0),
            )
        )

    filtered_users.sort(key=lambda row: row[4], reverse=True)

    filtered_user_count = len(filtered_users)
    users = filtered_users[offset:offset + per_page]

    admin_vehicles = []
    for vehicle_doc in all_vehicle_docs:
        vehicle_data = vehicle_doc.to_dict() or {}
        if vehicle_data.get("userId") == str(current_user.id):
            admin_vehicles.append(
                (
                    vehicle_doc.id,
                    vehicle_data.get("vehicleNumber", ""),
                    vehicle_data.get("callNumber", ""),
                    vehicle_data.get("token", ""),
                )
            )

    total_users = len(all_user_docs)
    blocked_users = sum(
        1 for user_doc in all_user_docs if is_user_blocked(user_doc.to_dict() or {})
    )
    active_users = total_users - blocked_users
    total_vehicles = len(all_vehicle_docs)

    total_pages = (filtered_user_count + per_page - 1) // per_page

    return render_template(
        "admin_dashboard.html",
        users=users,
        admin_vehicles=admin_vehicles,
        page=page,
        total_pages=total_pages,
        search=search,
        role_filter=role_filter,
        status_filter=status_filter,
        total_users=total_users,
        active_users=active_users,
        blocked_users=blocked_users,
        total_vehicles=total_vehicles
    )
        
# ==============================
# Block / Unblock Route 
# ==============================

@app.route("/admin/toggle-block/<user_id>")
@login_required
def toggle_block(user_id):

    if current_user.role != "admin":
        flash("Access denied.")
        return redirect(url_for("dashboard"))

    if str(user_id) == str(current_user.id):
        flash("You cannot block yourself.")
        return redirect(url_for("admin_dashboard"))

    user_ref = db.collection("users").document(str(user_id))
    user_doc = user_ref.get()
    if not user_doc.exists:
        flash("User not found.")
        return redirect(url_for("admin_dashboard"))

    user_data = user_doc.to_dict() or {}
    blocked = is_user_blocked(user_data)
    user_ref.set({"isBlocked": not blocked}, merge=True)

    flash("User status updated.")
    return redirect(url_for("admin_dashboard"))

# ==============================
# Transfer Admin Route 
# ==============================
@app.route("/admin/transfer/<user_id>")
@login_required
def transfer_admin(user_id):

    if current_user.role != "admin":
        flash("Access denied.")
        return redirect(url_for("dashboard"))

    if str(user_id) == str(current_user.id):
        flash("You are already admin.")
        return redirect(url_for("admin_dashboard"))

    target_ref = db.collection("users").document(str(user_id))
    target_doc = target_ref.get()

    if not target_doc.exists:
        flash("Target user not found.")
        return redirect(url_for("admin_dashboard"))

    target_ref.set({"role": "admin"}, merge=True)
    db.collection("users").document(str(current_user.id)).set({"role": "owner"}, merge=True)

    flash("Admin ownership transferred successfully.")
    return redirect(url_for("logout"))




if __name__ == "__main__":
    app.run(debug=True)