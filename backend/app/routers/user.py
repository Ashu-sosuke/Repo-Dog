from typing import Dict, Any
from fastapi import APIRouter, Depends
from app.core.security import verify_firebase_token
from app.core.supabase_client import get_supabase_client
from app.services.github_service import GitHubSyncService
from app.core.cache import cache

router = APIRouter(prefix="/user", tags=["User"])

@router.get("/description")
async def get_user_description(
    firebase_user: Dict[str, Any] = Depends(verify_firebase_token)
):
    firebase_uid = firebase_user.get("uid")
    cache_key = f"user_description:{firebase_uid}"
    
    cached = cache.get(cache_key)
    # Only return cached if it has valid profile data
    if cached and cached.get("login"):
        return cached

    client = get_supabase_client()
    profile = {}
    
    if client:
        try:
            u_res = client.table("users").select("*").eq("firebase_uid", firebase_uid).execute()
            if u_res.data:
                db_user = u_res.data[0]
                user_id = db_user["id"]
                github_username = db_user.get("github_username") or "Ashu-sosuke"
                
                profile = {
                    "db_id": user_id,
                    "firebase_uid": firebase_uid,
                    "email": db_user.get("email"),
                    "github_username": github_username,
                    "avatar_url": db_user.get("avatar_url"),
                    "created_at": db_user.get("created_at")
                }
                
                access_token = await GitHubSyncService.get_user_access_token(user_id)
                gh_profile = {}
                
                if access_token:
                    gh_profile = await GitHubSyncService.fetch_user_profile_full(access_token)
                
                # Fallback to fetching by username if token fetch was empty
                if not gh_profile.get("login") and github_username:
                    gh_profile = await GitHubSyncService.fetch_user_profile_by_username(github_username, access_token)

                if gh_profile:
                    profile.update({
                        "login": gh_profile.get("login") or github_username,
                        "name": gh_profile.get("name") or gh_profile.get("login") or github_username,
                        "avatar_url": gh_profile.get("avatar_url") or db_user.get("avatar_url"),
                        "bio": gh_profile.get("bio") or "No bio provided.",
                        "blog": gh_profile.get("blog"),
                        "location": gh_profile.get("location"),
                        "company": gh_profile.get("company"),
                        "twitter_username": gh_profile.get("twitter_username"),
                        "html_url": gh_profile.get("html_url", f"https://github.com/{github_username}"),
                        "public_repos": gh_profile.get("public_repos", 0),
                        "followers": gh_profile.get("followers", 0),
                        "following": gh_profile.get("following", 0),
                        "profile_readme": gh_profile.get("profile_readme")
                    })
        except Exception as e:
            print(f"Error building user description: {e}")

    if profile and profile.get("login"):
        cache.set(cache_key, profile, ttl_seconds=300)
    return profile
