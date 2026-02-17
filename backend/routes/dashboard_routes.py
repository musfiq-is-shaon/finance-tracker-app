from flask import Blueprint, jsonify
from services.supabase_service import get_client
from utils.jwt_handler import decode_token

dashboard_bp = Blueprint('dashboard', __name__)

def get_user_from_token():
    from flask import request
    auth_header = request.headers.get('Authorization')
    if not auth_header:
        return None
    
    try:
        token = auth_header.split(' ')[1]
        payload = decode_token(token)
        return payload.get('user_id') if payload else None
    except:
        return None

@dashboard_bp.route('', methods=['GET'])
def get_dashboard():
    user_id = get_user_from_token()
    if not user_id:
        return jsonify({'message': 'Unauthorized'}), 401
    
    supabase = get_client()
    
    # Get all transactions
    tx_response = supabase.table('transactions').select('*').eq('user_id', user_id).execute()
    transactions = tx_response.data
    
    # Get all loans
    loan_response = supabase.table('loans').select('*').eq('user_id', user_id).execute()
    loans = loan_response.data
    
    # Calculate totals from transactions
    total_income = sum(t['amount'] for t in transactions if t['type'] == 'income')
    total_expenses = sum(t['amount'] for t in transactions if t['type'] == 'expense')
    
    # Calculate loans (only outstanding/unpaid loans)
    # Loan Given: money going OUT (decreases balance) - only unpaid
    # Loan Borrowed: money coming IN (increases balance) - only unpaid
    total_loan_given = sum(
        l['amount'] - (l.get('paid_amount') or 0) 
        for l in loans 
        if l['type'] == 'given' and not l.get('is_paid', False)
    )
    total_loan_borrowed = sum(
        l['amount'] - (l.get('paid_amount') or 0) 
        for l in loans 
        if l['type'] == 'borrowed' and not l.get('is_paid', False)
    )
    
    # Total Money = Income - Expenses + Borrowed - Given
    total_balance = total_income - total_expenses + total_loan_borrowed - total_loan_given
    
    # Monthly data
    monthly_data = {}
    for t in transactions:
        month = t['date'][:7]  # YYYY-MM
        if month not in monthly_data:
            monthly_data[month] = {'income': 0, 'expense': 0}
        if t['type'] == 'income':
            monthly_data[month]['income'] += t['amount']
        else:
            monthly_data[month]['expense'] += t['amount']
    
    # Sort by month and take last 6 months
    sorted_months = sorted(monthly_data.keys())[-6:]
    monthly_list = [{'month': m, **monthly_data[m]} for m in sorted_months]
    
    # Recent transactions (last 10)
    recent_transactions = sorted(transactions, key=lambda x: x['date'], reverse=True)[:10]
    
    return jsonify({
        'total_balance': total_balance,
        'total_income': total_income,
        'total_expenses': total_expenses,
        'loan_given': total_loan_given,
        'loan_borrowed': total_loan_borrowed,
        'monthly_data': monthly_list,
        'recent_transactions': recent_transactions
    }), 200


@dashboard_bp.route('/balance', methods=['GET'])
def get_balance():
    """Get current balance for validation purposes"""
    user_id = get_user_from_token()
    if not user_id:
        return jsonify({'message': 'Unauthorized'}), 401
    
    supabase = get_client()
    
    # Get all transactions
    tx_response = supabase.table('transactions').select('*').eq('user_id', user_id).execute()
    transactions = tx_response.data
    
    # Get all loans (only unpaid)
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
    total_balance = total_income - total_expenses + total_loan_borrowed - total_loan_given
    
    return jsonify({
        'balance': total_balance,
        'total_income': total_income,
        'total_expenses': total_expenses,
        'loan_given': total_loan_given,
        'loan_borrowed': total_loan_borrowed
    }), 200

