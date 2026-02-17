from flask import Blueprint, request, jsonify
from services.supabase_service import get_client
from utils.jwt_handler import decode_token
import uuid

transaction_bp = Blueprint('transactions', __name__)

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


@transaction_bp.route('', methods=['GET'])
def get_transactions():
    user_id = get_user_from_token()
    if not user_id:
        return jsonify({'message': 'Unauthorized'}), 401
    
    supabase = get_client()
    
    category = request.args.get('category')
    start_date = request.args.get('start_date')
    end_date = request.args.get('end_date')
    
    query = supabase.table('transactions').select('*').eq('user_id', user_id)
    
    if category:
        query = query.eq('category', category)
    if start_date:
        query = query.gte('date', start_date)
    if end_date:
        query = query.lte('date', end_date)
    
    response = query.order('date', desc=True).execute()
    
    return jsonify({'transactions': response.data}), 200

@transaction_bp.route('', methods=['POST'])
def add_transaction():
    user_id = get_user_from_token()
    if not user_id:
        return jsonify({'message': 'Unauthorized'}), 401
    
    data = request.get_json()
    
    transaction_type = data.get('type')
    amount = float(data.get('amount', 0))
    
    # Check balance for expenses
    if transaction_type == 'expense':
        current_balance = calculate_balance(user_id)
        if amount > current_balance:
            return jsonify({
                'message': 'Insufficient balance',
                'current_balance': current_balance,
                'required': amount
            }), 400
    
    transaction_data = {
        'id': str(uuid.uuid4()),
        'user_id': user_id,
        'type': transaction_type,
        'amount': amount,
        'category': data.get('category'),
        'description': data.get('description', ''),
        'date': data.get('date'),
        'created_at': data.get('created_at')
    }
    
    supabase = get_client()
    response = supabase.table('transactions').insert(transaction_data).execute()
    
    if response.data:
        return jsonify({'message': 'Transaction added', 'transaction': response.data[0]}), 201
    return jsonify({'message': 'Failed to add transaction'}), 400

@transaction_bp.route('/<transaction_id>', methods=['PUT'])
def update_transaction(transaction_id):
    user_id = get_user_from_token()
    if not user_id:
        return jsonify({'message': 'Unauthorized'}), 401
    
    data = request.get_json()
    
    supabase = get_client()
    response = supabase.table('transactions').update(data).eq('id', transaction_id).eq('user_id', user_id).execute()
    
    if response.data:
        return jsonify({'message': 'Transaction updated', 'transaction': response.data[0]}), 200
    return jsonify({'message': 'Failed to update transaction'}), 400

@transaction_bp.route('/<transaction_id>', methods=['DELETE'])
def delete_transaction(transaction_id):
    user_id = get_user_from_token()
    if not user_id:
        return jsonify({'message': 'Unauthorized'}), 401
    
    supabase = get_client()
    response = supabase.table('transactions').delete().eq('id', transaction_id).eq('user_id', user_id).execute()
    
    return jsonify({'message': 'Transaction deleted'}), 200

