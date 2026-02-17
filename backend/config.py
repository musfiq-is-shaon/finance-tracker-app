import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    SUPABASE_URL = os.getenv('SUPABASE_URL')
    SUPABASE_KEY = os.getenv('SUPABASE_KEY')
    SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_KEY')
    JWT_SECRET = os.getenv('JWT_SECRET')
    FLASK_ENV = os.getenv('FLASK_ENV', 'development')
    FLASK_DEBUG = int(os.getenv('FLASK_DEBUG', 1))

