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


def calculate_balance(user_id):
    """Calculate current balance including loans"""
    supabase = get_client()
    
    # Get all transactions
    tx_response = supabase.table('transactions').select('*').eq('user_id', user_id).execute()
    transactions = tx_response.data
    
    # Get all unpaid loans
    loan_response = supabase.table('loans').select('*').eq('user_id', user_id).eq('is_paid', False).execute()
    loans = loan_response.data
    
    # Calculate totals
    total_income = sum(t['amount'] for t in transactions if t['type'] == 'income')
    total_expenses = sum(t['amount'] for t in transactions if t['type'] == 'expense')
    
    total_loan_given = sum(
        l['amount'] - (l.get('paid_amount') or 0) 
        for l in loans 
        if l['type'] == 'given'
    )
    total_loan_borrowed = sum(
        l['amount'] - (l.get('paid_amount') or 0) 
        for l in loans 
        if l['type'] == 'borrowed'
    )
    
    # Total Money = Income - Expenses + Borrowed - Given
    return total_income - total_expenses + total_loan_borrowed - total_loan_given


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
    
    loan_type = data.get('type')
    amount = float(data.get('amount', 0))
    
    # Check balance for "loan given" - cannot give more than current balance
    if loan_type == 'given':
        current_balance = calculate_balance(user_id)
        if amount > current_balance:
            return jsonify({
                'message': 'Insufficient balance to give this loan',
                'current_balance': current_balance,
                'required': amount
            }), 400
    
    loan_data = {
        'id': str(uuid.uuid4()),
        'user_id': user_id,
        'type': loan_type,
        'person_name': data.get('person_name'),
        'phone_number': data.get('phone_number'),
        'amount': amount,
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

