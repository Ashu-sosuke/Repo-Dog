from typing import Dict, Any, Optional
from fastapi import APIRouter, Depends, BackgroundTasks, HTTPException
from app.core.security import verify_firebase_token
from app.core.supabase_client import get_supabase_client
from app.services.github_service import GitHubSyncService
from app.core.cache import cache

router = APIRouter(prefix="/sync", tags=["GitHub Sync"])

@router.post("/all")
async def trigger_sync_all(
    background_tasks: BackgroundTasks,
    sync_now: bool = False,
    firebase_user: Dict[str, Any] = Depends(verify_firebase_token)
):
    firebase_uid = firebase_user.get("uid")
    print(f"[POST /sync/all] Triggered by firebase_uid={firebase_uid}")
    cache.invalidate()  # Purge stale cached responses so fresh data will be fetched after sync
    client = get_supabase_client()
    
    if not client:
        raise HTTPException(status_code=500, detail="Database client unavailable")
        
    u_res = client.table("users").select("id").eq("firebase_uid", firebase_uid).execute()
    if not u_res.data:
        print(f"[Sync Error] User not found in Supabase users table for firebase_uid={firebase_uid}")
        raise HTTPException(status_code=404, detail="User record not found in database. Complete auth callback first.")
        
    user_db_id = u_res.data[0]["id"]
    
    if sync_now:
        result = await GitHubSyncService.sync_all_user_repos(user_db_id)
        return result
    else:
        background_tasks.add_task(GitHubSyncService.sync_all_user_repos, user_db_id)
        return {
            "status": "started",
            "message": "GitHub synchronization job started in background.",
            "user_id": user_db_id
        }
