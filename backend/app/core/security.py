import os
import base64
from typing import Dict, Any, Optional
from fastapi import HTTPException, Security, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import firebase_admin
from firebase_admin import auth as firebase_auth, credentials
from cryptography.fernet import Fernet
from app.core.config import settings

# Initialize Firebase Admin SDK
_firebase_app = None

def get_firebase_app():
    global _firebase_app
    if _firebase_app:
        return _firebase_app
    
    try:
        if settings.FIREBASE_SERVICE_ACCOUNT_JSON and os.path.exists(settings.FIREBASE_SERVICE_ACCOUNT_JSON):
            cred = credentials.Certificate(settings.FIREBASE_SERVICE_ACCOUNT_JSON)
            _firebase_app = firebase_admin.initialize_app(cred)
        else:
            # Fallback to default application credentials or project ID
            _firebase_app = firebase_admin.initialize_app(options={'projectId': settings.FIREBASE_PROJECT_ID})
    except Exception as e:
        print(f"Warning: Firebase Admin initialization failed: {e}")
        _firebase_app = None
    return _firebase_app

# Fernet Cipher helper
def get_fernet_cipher() -> Fernet:
    key = settings.TOKEN_ENCRYPTION_KEY
    try:
        # If key is already valid Fernet key
        return Fernet(key.encode('utf-8'))
    except Exception:
        # Generate padded 32-byte key if raw key passed
        padded_key = base64.urlsafe_b64encode(key.ljust(32)[:32].encode('utf-8'))
        return Fernet(padded_key)

def encrypt_token(plain_token: str) -> str:
    cipher = get_fernet_cipher()
    return cipher.encrypt(plain_token.encode('utf-8')).decode('utf-8')

def decrypt_token(encrypted_token: str) -> str:
    cipher = get_fernet_cipher()
    return cipher.decrypt(encrypted_token.encode('utf-8')).decode('utf-8')

security_bearer = HTTPBearer(auto_error=False)

async def verify_firebase_token(
    credentials_auth: Optional[HTTPAuthorizationCredentials] = Security(security_bearer)
) -> Dict[str, Any]:
    if not credentials_auth or not credentials_auth.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization header",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    id_token = credentials_auth.credentials
    
    # In development/mock mode if token is 'mock_dev_token'
    if id_token.startswith("mock_dev_token"):
        uid = id_token.replace("mock_dev_token_", "") or "dev_user_123"
        return {
            "uid": uid,
            "email": "dev@example.com",
            "name": "Developer User",
            "picture": "https://github.com/ghost.png"
        }

    app = get_firebase_app()
    if not app:
        # If Firebase admin is not configured yet, fallback for dev testing
        return {
            "uid": "dev_firebase_uid",
            "email": "dev@example.com",
            "name": "Dev User"
        }
        
    try:
        decoded_token = firebase_auth.verify_id_token(id_token)
        return decoded_token
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid or expired Firebase ID token: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )
