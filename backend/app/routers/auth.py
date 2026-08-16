from typing import Dict, Any, Optional, List
from fastapi import APIRouter, Depends, HTTPException, status
import httpx
from pydantic import BaseModel
from app.core.security import verify_firebase_token, encrypt_token
from app.core.supabase_client import get_supabase_client
from app.core.config import settings

router = APIRouter(prefix="/auth", tags=["Auth"])

class GitHubCodeExchangeRequest(BaseModel):
    """Used by Android: exchange OAuth authorization code for access token."""
    code: str
    github_user_id: Optional[int] = None
    github_username: Optional[str] = None
    email: Optional[str] = None
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None

class GitHubCallbackRequest(BaseModel):
    # Optional on Android: signInWithProvider does not expose the raw OAuth
    # access token via OAuthCredential.accessToken (Firebase SDK limitation).
    # The user record is still created; token storage is skipped when None.
    github_access_token: Optional[str] = None
    github_user_id: Optional[int] = None
    github_username: Optional[str] = None
    email: Optional[str] = None
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    scopes: Optional[List[str]] = None

@router.post("/github/callback")
async def github_auth_callback(
    payload: GitHubCallbackRequest,
    firebase_user: Dict[str, Any] = Depends(verify_firebase_token)
):
    firebase_uid = firebase_user.get("uid")
    if not firebase_uid:
        raise HTTPException(status_code=400, detail="Invalid Firebase user session")
    
    email = payload.email or firebase_user.get("email")
    display_name = payload.display_name or firebase_user.get("name")
    avatar_url = payload.avatar_url or firebase_user.get("picture")
    github_username = payload.github_username
    
    client = get_supabase_client()
    user_db_id = None
    
    if client:
        try:
            # 1. Upsert User
            user_res = client.table("users").upsert(
                {
                    "firebase_uid": firebase_uid,
                    "email": email,
                    "display_name": display_name,
                    "avatar_url": avatar_url,
                    "github_username": github_username
                },
                on_conflict="firebase_uid"
            ).execute()
            
            if user_res.data and len(user_res.data) > 0:
                user_db_id = user_res.data[0]["id"]
            else:
                # Fetch user id if already existed
                existing = client.table("users").select("id").eq("firebase_uid", firebase_uid).execute()
                if existing.data:
                    user_db_id = existing.data[0]["id"]
            
            # 2. Encrypt token and save Github Account if valid token provided
            if user_db_id and payload.github_access_token and not payload.github_access_token.startswith("NO_TOKEN"):
                encrypted_token = encrypt_token(payload.github_access_token)
                try:
                    # Remove existing entry for this user first
                    client.table("github_accounts").delete().eq("user_id", user_db_id).execute()
                except Exception:
                    pass
                client.table("github_accounts").insert(
                    {
                        "user_id": user_db_id,
                        "github_user_id": payload.github_user_id,
                        "access_token_encrypted": encrypted_token,
                        "scopes": payload.scopes or ["repo", "read:user"],
                        "is_valid": True
                    }
                ).execute()
                print(f"[Auth] GitHub token saved for user_db_id={user_db_id}")
        except Exception as e:
            print(f"Error persisting auth data to Supabase: {e}")
            # Non-blocking for mock dev mode
    
    return {
        "status": "success",
        "message": "GitHub account successfully linked",
        "firebase_uid": firebase_uid,
        "user_id": user_db_id
    }

@router.post("/github/exchange-code")
async def exchange_github_code(
    payload: GitHubCodeExchangeRequest,
    firebase_user: Dict[str, Any] = Depends(verify_firebase_token)
):
    """
    Android OAuth flow: exchange authorization code for GitHub access token.
    The mobile client cannot safely hold the client_secret, so the backend
    performs the code→token exchange on its behalf.
    Redirect URI must match what the GitHub OAuth App is configured with.
    """
    firebase_uid = firebase_user.get("uid")
    if not firebase_uid:
        raise HTTPException(status_code=400, detail="Invalid Firebase user session")

    if not settings.GITHUB_OAUTH_CLIENT_ID or not settings.GITHUB_OAUTH_CLIENT_SECRET:
        raise HTTPException(status_code=500, detail="GitHub OAuth app not configured on server")

    # Exchange authorization code for access token via GitHub
    async with httpx.AsyncClient() as client:
        token_resp = await client.post(
            "https://github.com/login/oauth/access_token",
            data={
                "client_id": settings.GITHUB_OAUTH_CLIENT_ID,
                "client_secret": settings.GITHUB_OAUTH_CLIENT_SECRET,
                "code": payload.code,
                "redirect_uri": "repodog://callback",
            },
            headers={"Accept": "application/json"},
            timeout=15.0,
        )

    if token_resp.status_code != 200:
        raise HTTPException(status_code=502, detail="GitHub token exchange failed")

    token_data = token_resp.json()
    access_token = token_data.get("access_token")
    if not access_token:
        error = token_data.get("error_description", token_data.get("error", "Unknown"))
        raise HTTPException(status_code=400, detail=f"GitHub denied code exchange: {error}")

    print(f"[Auth] Android code exchange successful — token starts with {access_token[:6]}...")

    # Fetch GitHub user profile with the fresh token
    async with httpx.AsyncClient() as client:
        user_resp = await client.get(
            "https://api.github.com/user",
            headers={
                "Authorization": f"Bearer {access_token}",
                "Accept": "application/vnd.github.v3+json",
            },
            timeout=10.0,
        )
    gh_profile = user_resp.json() if user_resp.status_code == 200 else {}

    email = payload.email or gh_profile.get("email") or firebase_user.get("email")
    display_name = payload.display_name or gh_profile.get("name") or firebase_user.get("name")
    avatar_url = payload.avatar_url or gh_profile.get("avatar_url") or firebase_user.get("picture")
    github_username = payload.github_username or gh_profile.get("login")
    github_user_id = payload.github_user_id or gh_profile.get("id")

    # Upsert user and store encrypted token (same as /github/callback web flow)
    db = get_supabase_client()
    user_db_id = None
    if db:
        try:
            user_res = db.table("users").upsert(
                {
                    "firebase_uid": firebase_uid,
                    "email": email,
                    "display_name": display_name,
                    "avatar_url": avatar_url,
                    "github_username": github_username,
                },
                on_conflict="firebase_uid"
            ).execute()
            if user_res.data:
                user_db_id = user_res.data[0]["id"]
            else:
                existing = db.table("users").select("id").eq("firebase_uid", firebase_uid).execute()
                if existing.data:
                    user_db_id = existing.data[0]["id"]

            if user_db_id:
                encrypted = encrypt_token(access_token)
                try:
                    db.table("github_accounts").delete().eq("user_id", user_db_id).execute()
                except Exception:
                    pass
                db.table("github_accounts").insert({
                    "user_id": user_db_id,
                    "github_user_id": github_user_id,
                    "access_token_encrypted": encrypted,
                    "scopes": ["repo", "read:user"],
                    "is_valid": True,
                }).execute()
                print(f"[Auth] Android token saved for user_db_id={user_db_id}")
        except Exception as e:
            print(f"[Auth] Error saving Android token: {e}")

    return {
        "status": "success",
        "message": "GitHub token exchanged and stored",
        "firebase_uid": firebase_uid,
        "user_id": user_db_id,
        "github_username": github_username,
    }

@router.get("/me")

async def get_current_user_profile(
    firebase_user: Dict[str, Any] = Depends(verify_firebase_token)
):
    firebase_uid = firebase_user.get("uid")
    client = get_supabase_client()
    
    user_data = None
    github_connected = False
    
    if client:
        try:
            res = client.table("users").select("*, github_accounts(*)").eq("firebase_uid", firebase_uid).execute()
            if res.data and len(res.data) > 0:
                user_data = res.data[0]
                github_accounts = user_data.get("github_accounts", [])
                github_connected = len(github_accounts) > 0 and github_accounts[0].get("is_valid", False)
        except Exception as e:
            print(f"Database error on /me: {e}")

    return {
        "firebase_uid": firebase_uid,
        "email": firebase_user.get("email"),
        "display_name": firebase_user.get("name"),
        "avatar_url": firebase_user.get("picture"),
        "db_user": user_data,
        "github_connected": github_connected
    }
