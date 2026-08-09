import os
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    FIREBASE_PROJECT_ID: str = "demo-project"
    FIREBASE_SERVICE_ACCOUNT_JSON: str = ""
    
    SUPABASE_URL: str = "https://demo.supabase.co"
    SUPABASE_SERVICE_ROLE_KEY: str = "demo-key"
    
    GITHUB_OAUTH_CLIENT_ID: str = ""
    GITHUB_OAUTH_CLIENT_SECRET: str = ""
    
    # 32 base64 urlsafe bytes string for Fernet encryption
    TOKEN_ENCRYPTION_KEY: str = "dGVzdF9rZXlfZm9yX2RlbW9fcHVycG9zZXNfMTIzNDU2Nzg="

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

settings = Settings()
