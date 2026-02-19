from flask import Blueprint, jsonify, request
from services.supabase_service import get_client
from utils.jwt_handler import decode_token

dashboard_bp = Blueprint('dashboard', __name__)

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
    """Calculate current balance including all loan activities"""
    supabase = get_client()
    
    # Get all transactions
    tx_response = supabase.table('transactions').select('*').eq('user_id', user_id).execute()
    transactions = tx_response.data
    
    # Get all loan activities from new loan system
    activities_response = supabase.table('loan_activities').select('*').eq('user_id', user_id).execute()
    activities = activities_response.data
    
    # Also get old loans for backward compatibility
    old_loans_response = supabase.table('loans').select('*').eq('user_id', user_id).execute()
    old_loans = old_loans_response.data
    
    # Calculate totals from transactions
    total_income = sum(t['amount'] for t in transactions if t['type'] == 'income')
    total_expenses = sum(t['amount'] for t in transactions if t['type'] == 'expense')
    
    # Calculate from new loan activities
    # Given: money going OUT (decreases balance)
    # Borrowed: money coming IN (increases balance)
    # Payment received: money coming IN (increases balance)
    # Payment made: money going OUT (decreases balance)
    
    total_loan_given = sum(a['amount'] for a in activities if a['activity_type'] == 'given')
    total_loan_borrowed = sum(a['amount'] for a in activities if a['activity_type'] == 'borrowed')
    total_payment_received = sum(a['amount'] for a in activities if a['activity_type'] == 'payment_received')
    total_payment_made = sum(a['amount'] for a in activities if a['activity_type'] == 'payment_made')
    
    # Also include old loans for backward compatibility
    old_loan_given = sum(
        l['amount'] - (l.get('paid_amount') or 0) 
        for l in old_loans 
        if l['type'] == 'given' and not l.get('is_paid', False)
    )
    old_loan_borrowed = sum(
        l['amount'] - (l.get('paid_amount') or 0) 
        for l in old_loans 
        if l['type'] == 'borrowed' and not l.get('is_paid', False)
    )
    
    # Combine old and new loan data
    total_given = total_loan_given + old_loan_given
    total_borrowed = total_loan_borrowed + old_loan_borrowed
    
    # Calculate current outstanding from loan contacts
    # Get latest balance for each contact
    contacts_response = supabase.table('loan_contacts').select('id').eq('user_id', user_id).execute()
    contact_ids = [c['id'] for c in contacts_response.data]
    
    outstanding_given = 0
    outstanding_borrowed = 0
    
    for contact_id in contact_ids:
        latest = supabase.table('loan_activities').select('balance_after').eq('contact_id', contact_id).order('created_at', desc=True).limit(1).execute()
        if latest.data:
            balance = latest.data[0]['balance_after']
            if balance > 0:
                outstanding_given += balance
            else:
                outstanding_borrowed += abs(balance)
    
    # Add old loans outstanding
    outstanding_given += old_loan_given
    outstanding_borrowed += old_loan_borrowed
    
    # Total Balance = Income - Expenses - Given + Borrowed + PaymentReceived - PaymentMade
    total_balance = total_income - total_expenses - total_loan_given + total_loan_borrowed + total_payment_received - total_payment_made - old_loan_given + old_loan_borrowed
    
    return {
        'total_balance': total_balance,
        'total_income': total_income,
        'total_expenses': total_expenses,
        'loan_given': total_given,
        'loan_borrowed': total_borrowed,
        'payment_received': total_payment_received,
        'payment_made': total_payment_made,
        'outstanding_given': outstanding_given,
        'outstanding_borrowed': outstanding_borrowed,
    }


@dashboard_bp.route('', methods=['GET'])
def get_dashboard():
    user_id = get_user_from_token()
    if not user_id:
        return jsonify({'message': 'Unauthorized'}), 401
    
    balance_data = calculate_balance(user_id)
    
    supabase = get_client()
    
    # Get transactions for monthly data
    tx_response = supabase.table('transactions').select('*').eq('user_id', user_id).execute()
    transactions = tx_response.data
    
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
        'total_balance': balance_data['total_balance'],
        'total_income': balance_data['total_income'],
        'total_expenses': balance_data['total_expenses'],
        'loan_given': balance_data['outstanding_given'],
        'loan_borrowed': balance_data['outstanding_borrowed'],
        'monthly_data': monthly_list,
        'recent_transactions': recent_transactions
    }), 200


@dashboard_bp.route('/balance', methods=['GET'])
def get_balance():
    """Get current balance for validation purposes"""
    user_id = get_user_from_token()
    if not user_id:
        return jsonify({'message': 'Unauthorized'}), 401
    
    balance_data = calculate_balance(user_id)
    
    return jsonify({
        'balance': balance_data['total_balance'],
        'total_income': balance_data['total_income'],
        'total_expenses': balance_data['total_expenses'],
        'loan_given': balance_data['outstanding_given'],
        'loan_borrowed': balance_data['outstanding_borrowed']
    }), 200

