from flask import Flask, request, redirect, render_template, session, url_for
import sqlite3
import os

app = Flask(__name__)
app.secret_key = 'sanapati123'  # Tidak aman (rentan Session Hijacking)

DB_NAME = 'database.db'

# ==============================
# Inisialisasi database
# ==============================
def init_db():
    if not os.path.exists(DB_NAME):
        conn = sqlite3.connect(DB_NAME)
        cursor = conn.cursor()
        cursor.execute('''CREATE TABLE users (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            username TEXT,
                            password TEXT)''')
        cursor.execute('''CREATE TABLE orders (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            user_id INTEGER,
                            customer TEXT,
                            menu TEXT)''')
        conn.commit()
        conn.close()

# ==============================
# Handle favicon.ico (biar gak 404)
# ==============================
@app.route('/favicon.ico')
def favicon():
    return '', 204  # No Content, stop error 404

# ==============================
# Login (rentan SQL Injection)
# ==============================
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        conn = sqlite3.connect(DB_NAME)
        cursor = conn.cursor()
        query = f"SELECT * FROM users WHERE username = '{username}' AND password = '{password}'"
        cursor.execute(query)
        user = cursor.fetchone()
        conn.close()
        if user:
            session['user_id'] = user[0]
            return redirect('/home')
        return 'Login gagal!'
    return render_template('login.html')

# ==============================
# Register (juga rentan SQL Injection)
# ==============================
@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        conn = sqlite3.connect(DB_NAME)
        cursor = conn.cursor()
        cursor.execute(f"INSERT INTO users (username, password) VALUES ('{username}', '{password}')")
        conn.commit()
        conn.close()
        return redirect('/login')
    return render_template('register.html')

# ==============================
# Home
# ==============================
@app.route('/home')
def home():
    if 'user_id' not in session:
        return redirect('/login')
    return render_template('home.html')

# ==============================
# Pemesanan (rentan XSS)
# ==============================
@app.route('/order', methods=['GET', 'POST'])
def order():
    if 'user_id' not in session:
        return redirect('/login')
    if request.method == 'POST':
        customer = request.form['customer']  # Rentan XSS
        menu = request.form['menu']
        conn = sqlite3.connect(DB_NAME)
        cursor = conn.cursor()
        cursor.execute("INSERT INTO orders (user_id, customer, menu) VALUES (?, ?, ?)",
                       (session['user_id'], customer, menu))
        conn.commit()
        conn.close()
        return 'Pesanan berhasil!'
    return render_template('order.html')

# ==============================
# Lihat semua pesanan (rentan IDOR)
# ==============================
@app.route('/orders')
def orders():
    if 'user_id' not in session:
        return redirect('/login')
    user_id = request.args.get('id')  # Rentan IDOR
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    cursor.execute("SELECT customer, menu FROM orders WHERE user_id = ?", (user_id,))
    all_orders = cursor.fetchall()
    conn.close()
    return render_template('orders.html', orders=all_orders)

# ==============================
# Main entry
# ==============================
if __name__ == '__main__':
    init_db()
    app.run(debug=True)
