from flask import Blueprint, request, jsonify
from services.supabase_service import get_client
from utils.jwt_handler import create_token, decode_token

auth_bp = Blueprint('auth', __name__)

@auth_bp.route('/validate', methods=['POST'])
def validate_token():
    """Validate the JWT token and return user info if valid"""
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        return jsonify({'valid': False, 'message': 'No token provided'}), 401
    
    token = auth_header.split(' ')[1]
    payload = decode_token(token)
    
    if not payload:
        return jsonify({'valid': False, 'message': 'Invalid or expired token'}), 401
    
    user_id = payload.get('user_id')
    if not user_id:
        return jsonify({'valid': False, 'message': 'Invalid token payload'}), 401
    
    # Get user info from database
    supabase = get_client()
    try:
        profile_response = supabase.table('profiles').select('name').eq('id', user_id).execute()
        user_name = None
        if profile_response.data and len(profile_response.data) > 0:
            user_name = profile_response.data[0].get('name')
        
        return jsonify({
            'valid': True,
            'user_id': user_id,
            'name': user_name
        }), 200
    except Exception as e:
        return jsonify({'valid': False, 'message': str(e)}), 401

@auth_bp.route('/signup', methods=['POST'])
def signup():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')
    name = data.get('name')
    
    if not email or not password:
        return jsonify({'message': 'Email and password are required'}), 400
    
    if not name:
        return jsonify({'message': 'Name is required'}), 400
    
    supabase = get_client()
    
    try:
        response = supabase.auth.sign_up({
            "email": email,
            "password": password
        })
        
        if response.user:
            user_id = response.user.id
            
            # Update the profile with the user's name
            supabase.table('profiles').update({'name': name}).eq('id', user_id).execute()
            
            token = create_token(user_id, email)
            return jsonify({
                'message': 'User created successfully',
                'token': token,
                'user_id': user_id,
                'name': name
            }), 201
        else:
            return jsonify({'message': 'Failed to create user'}), 400
            
    except Exception as e:
        return jsonify({'message': str(e)}), 400

@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')
    
    if not email or not password:
        return jsonify({'message': 'Email and password are required'}), 400
    
    supabase = get_client()
    
    try:
        response = supabase.auth.sign_in_with_password({
            "email": email,
            "password": password
        })
        
        if response.user:
            # Check if email is confirmed
            if not response.user.email_confirmed_at:
                return jsonify({
                    'message': 'Please confirm your email address before logging in. Check your inbox for the confirmation link.'
                }), 401
            
            user_id = response.user.id
            
            # Get user's name from profiles table
            profile_response = supabase.table('profiles').select('name').eq('id', user_id).execute()
            user_name = None
            if profile_response.data and len(profile_response.data) > 0:
                user_name = profile_response.data[0].get('name')
            
            token = create_token(user_id, email)
            return jsonify({
                'message': 'Login successful',
                'token': token,
                'user_id': user_id,
                'name': user_name
            }), 200
        else:
            return jsonify({'message': 'Invalid credentials'}), 401
            
    except Exception as e:
        error_msg = str(e)
        if 'Email not confirmed' in error_msg:
            return jsonify({'message': 'Please confirm your email address before logging in. Check your inbox for the confirmation link.'}), 401
        return jsonify({'message': error_msg}), 401

