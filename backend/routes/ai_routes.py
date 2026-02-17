from flask import Blueprint, jsonify, request
from services.ai_service import generate_advice
from utils.jwt_handler import decode_token

ai_bp = Blueprint('ai', __name__)

def get_user_from_token():
    auth_header = request.headers.get('Authorization')
    if not auth_header:
        return None
    
    try:
        token = auth_header.split(' ')[1]
        payload = decode_token(token)
        return payload.get('user_id') if payload else None
    except:
        return None

@ai_bp.route('/advice', methods=['POST'])
def get_advice():
    user_id = get_user_from_token()
    if not user_id:
        return jsonify({'message': 'Unauthorized'}), 401
    
    advice = generate_advice(user_id)
    
    return jsonify({'advice': advice}), 200

