from flask import Flask
from flask_cors import CORS
from config import Config
from routes.auth_routes import auth_bp
from routes.transaction_routes import transaction_bp
from routes.loan_routes import loan_bp
from routes.loan_contacts_routes import loan_contacts_bp
from routes.dashboard_routes import dashboard_bp
from routes.ai_routes import ai_bp

app = Flask(__name__)
app.config.from_object(Config)

CORS(app, 
     resources={r"/api/*": {"origins": "*"}},
     allow_headers=["Content-Type", "Authorization", "Access-Control-Allow-Origin"],
     methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
     supports_credentials=True)

# Register blueprints
app.register_blueprint(auth_bp, url_prefix='/api/auth')
app.register_blueprint(transaction_bp, url_prefix='/api/transactions')
app.register_blueprint(loan_bp, url_prefix='/api/loans')
app.register_blueprint(loan_contacts_bp, url_prefix='/api/loan-contacts')
app.register_blueprint(dashboard_bp, url_prefix='/api/dashboard')
app.register_blueprint(ai_bp, url_prefix='/api/ai')

@app.route('/')
def index():
    return {'message': 'Finance Tracker API', 'status': 'running'}

@app.route('/health')
def health():
    return {'status': 'healthy'}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=False)

