from supabase import create_client, Client
from config import Config

_client = None

def get_client():
    global _client
    if _client is None:
        if not Config.SUPABASE_URL or not Config.SUPABASE_KEY:
            raise ValueError("SUPABASE_URL and SUPABASE_KEY must be set in .env")
        _client = create_client(Config.SUPABASE_URL, Config.SUPABASE_KEY)
    return _client

def get_service_client():
    if not Config.SUPABASE_URL or not Config.SUPABASE_SERVICE_KEY:
        raise ValueError("SUPABASE_URL and SUPABASE_SERVICE_KEY must be set in .env")
    return create_client(Config.SUPABASE_URL, Config.SUPABASE_SERVICE_KEY)

