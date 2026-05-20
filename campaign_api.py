# Campaign and User Account Administration API
# Built with Flask + PostgreSQL
# All logic for users and campaigns uses stored procedures.

import os
import psycopg2
import psycopg2.extras
from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
CORS(app)

# ---------------------------------------------------------------------------
# Database connection
# ---------------------------------------------------------------------------

def get_db():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", 5432),
        dbname=os.getenv("DB_NAME", "patient_registration"),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD", ""),
        cursor_factory=psycopg2.extras.RealDictCursor
    )


def success(data=None, status=200):
    return jsonify({"ok": True, "data": data}), status


def error(message, status=400):
    return jsonify({"ok": False, "error": message}), status


def run_query(sql, params=(), fetch="all"):
    conn = None
    try:
        conn = get_db()
        with conn.cursor() as cur:
            cur.execute(sql, params)
            conn.commit()
            if fetch == "all":
                return cur.fetchall()
            elif fetch == "one":
                return cur.fetchone()
            else:
                return None
    except psycopg2.Error as e:
        if conn:
            conn.rollback()
        raise e
    finally:
        if conn:
            conn.close()


# ---------------------------------------------------------------------------
# USER ACCOUNTS
# ---------------------------------------------------------------------------

@app.route("/login", methods=["POST"])
def login():
    """Authenticate credentials against database."""
    body = request.get_json()
    if not body:
        return error("request body is missing or not valid JSON")

    username = body.get("username")
    password = body.get("password")

    if not username or not password:
        return error("missing username or password")

    try:
        row = run_query(
            """
            SELECT u.id, u.first_name, u.last_name, u.email, u.role_id, r.role_name
            FROM users u
            JOIN roles r ON r.id = u.role_id
            WHERE u.email = %s AND u.password_hash = crypt(%s, u.password_hash) AND u.is_deleted = FALSE
            """,
            (username.strip(), password),
            fetch="one"
        )
        if not row:
            return error("Invalid email or password", 401)
        
        return success(dict(row))
    except Exception as e:
        return error(str(e), 500)


@app.route("/users", methods=["POST"])
def create_user():
    """Register a new system user (Coordinator, Optometrist, Volunteer)."""
    body = request.get_json()
    if not body:
        return error("request body is missing or not valid JSON")

    required = ["first_name", "last_name", "dob", "email", "role_id", "password"]
    missing = [f for f in required if not body.get(f)]
    if missing:
        return error(f"missing required fields: {', '.join(missing)}")

    # Specific DB constraint checks prior to calling procedues to ensure friendly messaging
    role_id = int(body.get("role_id"))
    if role_id == 4 and not body.get("npi"):
        return error("NPI number is required for Optometrist roles")
    if role_id in [3, 4] and not body.get("coordinator_id"):
        return error("Volunteer and Optometrist accounts must be assigned to a Coordinator")

    try:
        row = run_query(
            """
            SELECT * FROM create_user(
                %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
            )
            """,
            (
                body.get("first_name"),
                body.get("last_name"),
                body.get("dob"),
                body.get("phone"),
                body.get("email"),
                body.get("gender"),
                body.get("address"),
                body.get("city_id"),
                body.get("zip_code"),
                role_id,
                body.get("password"),
                body.get("npi"),
                body.get("coordinator_id")
            ),
            fetch="one"
        )
        return success(dict(row), status=201)
    except Exception as e:
        return error(str(e), 500)


@app.route("/users", methods=["GET"])
def list_users():
    """Get system operators with optional search filters."""
    first_name = request.args.get("first_name") or None
    last_name  = request.args.get("last_name")  or None
    city_id    = request.args.get("city_id",    type=int)
    role_id    = request.args.get("role_id",    type=int)

    try:
        rows = run_query(
            "SELECT * FROM get_users(%s, %s, %s, %s)",
            (first_name, last_name, city_id, role_id)
        )
        return success([dict(r) for r in rows])
    except Exception as e:
        return error(str(e), 500)


@app.route("/users/<int:user_id>", methods=["PUT"])
def update_user(user_id):
    """Update profile or credentials of an existing operator account."""
    body = request.get_json()
    if not body:
        return error("request body is missing or not valid JSON")

    required = ["first_name", "last_name", "dob", "email", "role_id"]
    missing = [f for f in required if not body.get(f)]
    if missing:
        return error(f"missing required fields: {', '.join(missing)}")

    try:
        run_query(
            """
            SELECT update_user(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (
                user_id,
                body.get("first_name"),
                body.get("last_name"),
                body.get("dob"),
                body.get("phone"),
                body.get("email"),
                body.get("gender"),
                body.get("address"),
                body.get("city_id"),
                body.get("zip_code"),
                int(body.get("role_id")),
                body.get("password"),  # Optional on update, procedures will ignore if null
                body.get("npi"),
                body.get("coordinator_id")
            ),
            fetch="none"
        )
        return success({"message": "user updated successfully"})
    except Exception as e:
        return error(str(e), 500)


@app.route("/users/<int:user_id>", methods=["DELETE"])
def disable_user(user_id):
    """Disable/soft-delete an operator account."""
    try:
        run_query("SELECT delete_user(%s)", (user_id,), fetch="none")
        return success({"message": "user account disabled successfully"})
    except Exception as e:
        return error(str(e), 500)


# ---------------------------------------------------------------------------
# CAMPAIGNS
# ---------------------------------------------------------------------------

@app.route("/campaigns", methods=["POST"])
def create_campaign():
    """Create a new eye care camp."""
    body = request.get_json()
    if not body:
        return error("request body is missing or not valid JSON")

    required = ["camp_name", "city_id", "camp_date", "coordinator_id"]
    missing = [f for f in required if not body.get(f)]
    if missing:
        return error(f"missing required fields: {', '.join(missing)}")

    try:
        row = run_query(
            """
            SELECT * FROM create_campaign(%s, %s, %s, %s, %s, %s, %s)
            """,
            (
                body.get("camp_name"),
                body.get("city_id"),
                body.get("camp_date"),
                body.get("status", "Scheduled"),
                body.get("coordinator_id"),
                body.get("volunteer_ids", []),
                body.get("optometrist_ids", [])
            ),
            fetch="one"
        )
        return success(dict(row), status=201)
    except Exception as e:
        return error(str(e), 500)


@app.route("/campaigns", methods=["GET"])
def get_campaigns():
    """List camps with optional filters."""
    camp_name  = request.args.get("camp_name") or None
    status     = request.args.get("status")    or None
    date_from  = request.args.get("date_from") or None
    date_to    = request.args.get("date_to")   or None
    city_id    = request.args.get("city_id",   type=int)

    try:
        rows = run_query(
            "SELECT * FROM get_campaigns(%s, %s, %s, %s, %s)",
            (camp_name, status, date_from, date_to, city_id)
        )
        return success([dict(r) for r in rows])
    except Exception as e:
        return error(str(e), 500)


@app.route("/campaigns/<int:campaign_id>", methods=["GET"])
def get_campaign(campaign_id):
    """Retrieve full details of a specific camp."""
    try:
        row = run_query(
            "SELECT * FROM get_campaign_by_id(%s)",
            (campaign_id,),
            fetch="one"
        )
        if not row:
            return error("campaign not found", 404)
        return success(dict(row))
    except Exception as e:
        return error(str(e), 500)


@app.route("/campaigns/<int:campaign_id>", methods=["PUT"])
def update_campaign(campaign_id):
    """Update details or personnel assignments of a camp."""
    body = request.get_json()
    if not body:
        return error("request body is missing or not valid JSON")

    try:
        run_query(
            """
            SELECT update_campaign(%s, %s, %s, %s, %s, %s, %s)
            """,
            (
                campaign_id,
                body.get("camp_name"),
                body.get("city_id"),
                body.get("camp_date"),
                body.get("status"),
                body.get("volunteer_ids", []),
                body.get("optometrist_ids", [])
            ),
            fetch="none"
        )
        return success({"message": "campaign updated successfully"})
    except Exception as e:
        return error(str(e), 500)


@app.route("/campaigns/<int:campaign_id>", methods=["DELETE"])
def delete_campaign(campaign_id):
    """Delete a camp."""
    try:
        run_query("SELECT delete_campaign(%s)", (campaign_id,), fetch="none")
        return success({"message": "campaign deleted successfully"})
    except Exception as e:
        return error(str(e), 500)


# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    app.run(debug=True, port=5002)
