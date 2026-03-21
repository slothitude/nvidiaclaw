from flask import Flask, request, jsonify
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime, timedelta
import jwt
import uuid
from functools import wraps

app = Flask(__name__)
app.config['SECRET_KEY'] = 'super-secret-key-change-in-production'

# In-memory SQLite (Flask default)
from flask_sqlalchemy import SQLAlchemy
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

# Models
class User(db.Model):
    id       = db.Column(db.Integer, primary_key=True)
    public_id= db.Column(db.String(50), unique=True)
    name     = db.Column(db.String(50))
    password = db.Column(db.String(128))

class Todo(db.Model):
    id       = db.Column(db.Integer, primary_key=True)
    text     = db.Column(db.String(200))
    complete = db.Column(db.Boolean)
    user_id  = db.Column(db.Integer)

# Helper: token required decorator
def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('x-access-token')
        if not token:
            return jsonify({'message': 'Token is missing!'}), 401
        try:
            data = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
            current_user = User.query.filter_by(public_id=data['public_id']).first()
        except:
            return jsonify({'message': 'Token is invalid!'}), 401
        return f(current_user, *args, **kwargs)
    return decorated

# Auth: Register
@app.route('/register', methods=['POST'])
def signup():
    data = request.get_json()
    if not data or not data.get('name') or not data.get('password'):
        return jsonify({'message': 'Missing credentials'}), 400
    if User.query.filter_by(name=data['name']).first():
        return jsonify({'message': 'User already exists'}), 409
    hashed_pw = generate_password_hash(data['password'], method='pbkdf2:sha256')
    new_user = User(public_id=str(uuid.uuid4()), name=data['name'], password=hashed_pw)
    db.session.add(new_user)
    db.session.commit()
    return jsonify({'message': 'User created'}), 201

# Auth: Login
@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    if not data or not data.get('name') or not data.get('password'):
        return jsonify({'message': 'Missing credentials'}), 400

    user = User.query.filter_by(name=data['name']).first()
    if not user or not check_password_hash(user.password, data['password']):
        return jsonify({'message': 'Invalid credentials'}), 401

    token = jwt.encode({'public_id': user.public_id, 'exp': datetime.utcnow() + timedelta(hours=24)},
                       app.config['SECRET_KEY'], algorithm='HS256')
    return jsonify({'token': token})

# Todo CRUD
@app.route('/todos', methods=['GET'])
@token_required
def get_todos(current_user):
    todos = Todo.query.filter_by(user_id=current_user.id).all()
    return jsonify([{'id': t.id, 'text': t.text, 'complete': t.complete} for t in todos])

@app.route('/todos', methods=['POST'])
@token_required
def create_todo(current_user):
    data = request.get_json()
    if not data or not data.get('text'):
        return jsonify({'message': 'Text required'}), 400
    todo = Todo(text=data['text'], complete=False, user_id=current_user.id)
    db.session.add(todo)
    db.session.commit()
    return jsonify({'id': todo.id, 'text': todo.text, 'complete': todo.complete}), 201

@app.route('/todos/<int:todo_id>', methods=['PUT'])
@token_required
def update_todo(current_user, todo_id):
    todo = Todo.query.filter_by(id=todo_id, user_id=current_user.id).first()
    if not todo:
        return jsonify({'message': 'Todo not found'}), 404
    data = request.get_json()
    todo.text = data.get('text', todo.text)
    todo.complete = data.get('complete', todo.complete)
    db.session.commit()
    return jsonify({'id': todo.id, 'text': todo.text, 'complete': todo.complete})

@app.route('/todos/<int:todo_id>', methods=['DELETE'])
@token_required
def delete_todo(current_user, todo_id):
    todo = Todo.query.filter_by(id=todo_id, user_id=current_user.id).first()
    if not todo:
        return jsonify({'message': 'Todo not found'}), 404
    db.session.delete(todo)
    db.session.commit()
    return jsonify({'message': 'Todo deleted'})

# Health check
@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'message': 'REST API is running'})

# Initialize DB
with app.app_context():
    db.create_all()

if __name__ == '__main__':
    print("=" * 60)
    print("  REST API - Built by Mr. Meeseeks #1")
    print("  Complete with: JWT Auth, Todo CRUD, SQLite")
    print("=" * 60)
    app.run(debug=True, port=5000)
