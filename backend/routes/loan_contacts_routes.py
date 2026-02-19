from flask import Blueprint, request, jsonify
from services.supabase_service import get_client
from utils.jwt_handler import decode_token
import uuid

loan_contacts_bp = Blueprint('loan_contacts', __name__)

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


@loan_contacts_bp.route('', methods=['GET'])
def get_contacts():
    user_id = get_user_from_token()
    if not user_id:
        return jsonify({'message': 'Unauthorized'}), 401
    
    supabase = get_client()
    response = supabase.table('loan_contacts').select('*').eq('user_id', user_id).order('updated_at', desc=True).execute()
    
    contacts = []
    for contact in response.data:
        # Get latest balance
        activities_response = supabase.table('loan_activities').select('balance_after').eq('contact_id', contact['id']).order('created_at', desc=True).limit(1).execute()
        
        current_balance = 0
        if activities_response.data:
            current_balance = activities_response.data[0].get('balance_after', 0)
        
        # Get activity count
        count_response = supabase.table('loan_activities').select('id', count='exact').eq('contact_id', contact['id']).execute()
        activity_count = count_response.count or 0
        
        contacts.append({
            **contact,
            'current_balance': current_balance,
            'activity_count': activity_count
        })
    
    return jsonify({'contacts': contacts}), 200


@loan_contacts_bp.route('', methods=['POST'])
def create_contact():
    user_id = get_user_from_token()
    if not user_id:
        return jsonify({'message': 'Unauthorized'}), 401
    
    data = request.get_json()
    
    supabase = get_client()
    
    # Check if contact with same name exists
    existing = supabase.table('loan_contacts').select('*').eq('user_id', user_id).ilike('name', data.get('name', '')).execute()
    if existing.data:
        return jsonify({'message': 'Contact with this name already exists', 'contact': existing.data[0]}), 409
    
    contact_data = {
        'id': str(uuid.uuid4()),
        'user_id': user_id,
        'name': data.get('name'),
        'phone_number': data.get('phone_number'),
        'email': data.get('email'),
        'notes': data.get('notes'),
        'initial_balance': data.get('initial_balance', 0),
    }
    
    response = supabase.table('loan_contacts').insert(contact_data).execute()
    
    if response.data:
        return jsonify({'message': 'Contact created', 'contact': response.data[0]}), 201
    return jsonify({'message': 'Failed to create contact'}), 400


@loan_contacts_bp.route('/<contact_id>', methods=['GET'])
def get_contact(contact_id):
    user_id = get_user_from_token()
    if not user_id:
        return jsonify({'message': 'Unauthorized'}), 401
    
    supabase = get_client()
    
    # Get contact
    contact_response = supabase.table('loan_contacts').select('*').eq('id', contact_id).eq('user_id', user_id).execute()
    if not contact_response.data:
        return jsonify({'message': 'Contact not found'}), 404
    
    contact = contact_response.data[0]
    
    # Get summary stats
    activities_response = supabase.table('loan_activities').select('activity_type', 'amount').eq('contact_id', contact_id).execute()
    
    total_given = sum(a['amount'] for a in activities_response.data if a['activity_type'] == 'given')
    total_borrowed = sum(a['amount'] for a in activities_response.data if a['activity_type'] == 'borrowed')
    total_paid_to_you = sum(a['amount'] for a in activities_response.data if a['activity_type'] == 'payment_received')
    total_you_paid = sum(a['amount'] for a in activities_response.data if a['activity_type'] == 'payment_made')
    
    # Get latest balance
    latest_activity = supabase.table('loan_activities').select('balance_after').eq('contact_id', contact_id).order('created_at', desc=True).limit(1).execute()
    current_balance = latest_activity.data[0]['balance_after'] if latest_activity.data else 0
    
    # Get all activities
    all_activities = supabase.table('loan_activities').select('*').eq('contact_id', contact_id).order('activity_date', desc=True).order('created_at', desc=True).execute()
    
    return jsonify({
        'contact': {
            **contact,
            'current_balance': current_balance,
            'total_given': total_given,
            'total_borrowed': total_borrowed,
            'total_paid_to_you': total_paid_to_you,
            'total_you_paid': total_you_paid,
            'activity_count': len(activities_response.data)
        },
        'activities': all_activities.data
    }), 200


@loan_contacts_bp.route('/<contact_id>', methods=['PUT'])
def update_contact(contact_id):
    user_id = get_user_from_token()
    if not user_id:
        return jsonify({'message': 'Unauthorized'}), 401
    
    data = request.get_json()
    
    supabase = get_client()
    
    # Check ownership
    existing = supabase.table('loan_contacts').select('id').eq('id', contact_id).eq('user_id', user_id).execute()
    if not existing.data:
        return jsonify({'message': 'Contact not found'}), 404
    
    update_data = {
        'name': data.get('name'),
        'phone_number': data.get('phone_number'),
        'email': data.get('email'),
        'notes': data.get('notes'),
        'updated_at': 'now()'
    }
    
    # Remove None values
    update_data = {k: v for k, v in update_data.items() if v is not None}
    
    response = supabase.table('loan_contacts').update(update_data).eq('id', contact_id).execute()
    
    if response.data:
        return jsonify({'message': 'Contact updated', 'contact': response.data[0]}), 200
    return jsonify({'message': 'Failed to update contact'}), 400


@loan_contacts_bp.route('/<contact_id>', methods=['DELETE'])
def delete_contact(contact_id):
    user_id = get_user_from_token()
    if not user_id:
        return jsonify({'message': 'Unauthorized'}), 401
    
    supabase = get_client()
    
    # Check ownership
    existing = supabase.table('loan_contacts').select('id').eq('id', contact_id).eq('user_id', user_id).execute()
    if not existing.data:
        return jsonify({'message': 'Contact not found'}), 404
    
    # Delete all activities first
    supabase.table('loan_activities').delete().eq('contact_id', contact_id).execute()
    
    # Delete contact
    supabase.table('loan_contacts').delete().eq('id', contact_id).execute()
    
    return jsonify({'message': 'Contact deleted'}), 200


@loan_contacts_bp.route('/<contact_id>/activities', methods=['GET'])
def get_activities(contact_id):
    user_id = get_user_from_token()
    if not user_id:
        return jsonify({'message': 'Unauthorized'}), 401
    
    supabase = get_client()
    
    # Verify ownership
    contact = supabase.table('loan_contacts').select('id').eq('id', contact_id).eq('user_id', user_id).execute()
    if not contact.data:
        return jsonify({'message': 'Contact not found'}), 404
    
    response = supabase.table('loan_activities').select('*').eq('contact_id', contact_id).order('activity_date', desc=True).order('created_at', desc=True).execute()
    
    return jsonify({'activities': response.data}), 200


@loan_contacts_bp.route('/<contact_id>/activities', methods=['POST'])
def add_activity(contact_id):
    user_id = get_user_from_token()
    if not user_id:
        return jsonify({'message': 'Unauthorized'}), 401
    
    data = request.get_json()
    activity_type = data.get('activity_type')
    amount = float(data.get('amount', 0))
    
    if amount <= 0:
        return jsonify({'message': 'Amount must be greater than 0'}), 400
    
    if activity_type not in ['given', 'borrowed', 'payment_received', 'payment_made']:
        return jsonify({'message': 'Invalid activity type'}), 400
    
    supabase = get_client()
    
    # Verify contact ownership
    contact = supabase.table('loan_contacts').select('*').eq('id', contact_id).eq('user_id', user_id).execute()
    if not contact.data:
        return jsonify({'message': 'Contact not found'}), 404
    
    # Get previous balance
    prev_activity = supabase.table('loan_activities').select('balance_after').eq('contact_id', contact_id).order('created_at', desc=True).limit(1).execute()
    previous_balance = prev_activity.data[0]['balance_after'] if prev_activity.data else 0
    
    # Calculate new balance
    if activity_type == 'given':
        new_balance = previous_balance + amount
    elif activity_type == 'borrowed':
        new_balance = previous_balance - amount
    elif activity_type == 'payment_received':
        new_balance = previous_balance - amount
    elif activity_type == 'payment_made':
        new_balance = previous_balance + amount
    
    activity_data = {
        'id': str(uuid.uuid4()),
        'user_id': user_id,
        'contact_id': contact_id,
        'activity_type': activity_type,
        'amount': amount,
        'balance_after': new_balance,
        'description': data.get('description'),
        'activity_date': data.get('activity_date') or data.get('date') or str(datetime.now().date()),
    }
    
    response = supabase.table('loan_activities').insert(activity_data).execute()
    
    # Update contact timestamp
    supabase.table('loan_contacts').update({'updated_at': 'now()'}).eq('id', contact_id).execute()
    
    if response.data:
        return jsonify({
            'message': 'Activity added',
            'activity': response.data[0],
            'new_balance': new_balance
        }), 201
    return jsonify({'message': 'Failed to add activity'}), 400


# Import datetime for the add_activity function
from datetime import datetime


@loan_contacts_bp.route('/<contact_id>/activities/<activity_id>', methods=['DELETE'])
def delete_activity(contact_id, activity_id):
    user_id = get_user_from_token()
    if not user_id:
        return jsonify({'message': 'Unauthorized'}), 401
    
    supabase = get_client()
    
    # Verify contact ownership
    contact = supabase.table('loan_contacts').select('id').eq('id', contact_id).eq('user_id', user_id).execute()
    if not contact.data:
        return jsonify({'message': 'Contact not found'}), 404
    
    # Get the activity to delete
    activity = supabase.table('loan_activities').select('*').eq('id', activity_id).eq('contact_id', contact_id).execute()
    if not activity.data:
        return jsonify({'message': 'Activity not found'}), 404
    
    activity_data = activity.data[0]
    deleted_activity_date = activity_data.get('activity_date')
    deleted_activity_type = activity_data['activity_type']
    deleted_amount = activity_data['amount']
    
    # Delete the activity
    supabase.table('loan_activities').delete().eq('id', activity_id).execute()
    
    # Get all remaining activities after the deleted one (in chronological order)
    remaining_activities = supabase.table('loan_activities').select('*').eq('contact_id', contact_id).order('activity_date', ascending=True).order('created_at', ascending=True).execute()
    
    # Recalculate balances for remaining activities
    # First, find the balance before the deleted activity
    prev_activity = supabase.table('loan_activities').select('balance_after').eq('contact_id', contact_id).lte('activity_date', deleted_activity_date).order('activity_date', desc=True).order('created_at', desc=True).limit(1).execute()
    
    previous_balance = prev_activity.data[0]['balance_after'] if prev_activity.data else 0
    
    # Now recalculate all subsequent activities
    for remaining in remaining_activities.data:
        # Calculate what the balance should be based on the new previous balance
        remaining_type = remaining['activity_type']
        remaining_amount = remaining['amount']
        
        if remaining_type == 'given':
            new_balance = previous_balance + remaining_amount
        elif remaining_type == 'borrowed':
            new_balance = previous_balance - remaining_amount
        elif remaining_type == 'payment_received':
            new_balance = previous_balance - remaining_amount
        elif remaining_type == 'payment_made':
            new_balance = previous_balance + remaining_amount
        else:
            new_balance = previous_balance
        
        # Update this activity's balance
        supabase.table('loan_activities').update({'balance_after': new_balance}).eq('id', remaining['id']).execute()
        
        # Set this as the new previous balance for the next iteration
        previous_balance = new_balance
    
    # Update contact's updated_at timestamp
    supabase.table('loan_contacts').update({'updated_at': 'now()'}).eq('id', contact_id).execute()
    
    return jsonify({'message': 'Activity deleted', 'new_balance': previous_balance}), 200

