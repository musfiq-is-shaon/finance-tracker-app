from flask import Blueprint, request, jsonify
from services.supabase_service import get_client
from utils.jwt_handler import decode_token
import uuid

loan_bp = Blueprint('loans', __name__)

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

@loan_bp.route('', methods=['GET'])
def get_loans():
    user_id = get_user_from_token()
    if not user_id:
        return jsonify({'message': 'Unauthorized'}), 401
    
    supabase = get_client()
    response = supabase.table('loans').select('*').eq('user_id', user_id).order('date', desc=True).execute()
    
    return jsonify({'loans': response.data}), 200

@loan_bp.route('', methods=['POST'])
def add_loan():
    user_id = get_user_from_token()
    if not user_id:
        return jsonify({'message': 'Unauthorized'}), 401
    
    data = request.get_json()
    
    loan_data = {
        'id': str(uuid.uuid4()),
        'user_id': user_id,
        'type': data.get('type'),
        'person_name': data.get('person_name'),
        'amount': data.get('amount'),
        'paid_amount': data.get('paid_amount'),
        'description': data.get('description'),
        'date': data.get('date'),
        'is_paid': data.get('is_paid', False),
        'created_at': data.get('created_at')
    }
    
    supabase = get_client()
    response = supabase.table('loans').insert(loan_data).execute()
    
    if response.data:
        return jsonify({'message': 'Loan added', 'loan': response.data[0]}), 201
    return jsonify({'message': 'Failed to add loan'}), 400

@loan_bp.route('/<loan_id>', methods=['PUT'])
def update_loan(loan_id):
    user_id = get_user_from_token()
    if not user_id:
        return jsonify({'message': 'Unauthorized'}), 401
    
    data = request.get_json()
    
    supabase = get_client()
    response = supabase.table('loans').update(data).eq('id', loan_id).eq('user_id', user_id).execute()
    
    if response.data:
        return jsonify({'message': 'Loan updated', 'loan': response.data[0]}), 200
    return jsonify({'message': 'Failed to update loan'}), 400

@loan_bp.route('/<loan_id>', methods=['DELETE'])
def delete_loan(loan_id):
    user_id = get_user_from_token()
    if not user_id:
        return jsonify({'message': 'Unauthorized'}), 401
    
    supabase = get_client()
    response = supabase.table('loans').delete().eq('id', loan_id).eq('user_id', user_id).execute()
    
    return jsonify({'message': 'Loan deleted'}), 200

