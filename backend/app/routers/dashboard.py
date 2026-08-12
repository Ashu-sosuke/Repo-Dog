from typing import Dict, Any
from fastapi import APIRouter, Depends
from app.core.security import verify_firebase_token
from app.core.supabase_client import get_supabase_client
from app.services.github_service import GitHubSyncService
from app.core.cache import cache

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])

@router.get("")
async def get_dashboard_summary(
    firebase_user: Dict[str, Any] = Depends(verify_firebase_token)
):
    firebase_uid = firebase_user.get("uid")
    cache_key = f"dashboard:{firebase_uid}"
    
    cached_response = cache.get(cache_key)
    if cached_response:
        return cached_response

    client = get_supabase_client()
    
    total_repos = 0
    open_prs = 0
    failing_workflows = 0
    active_branches = 0
    recent_repos = []
    starred_repos = []
    total_contributions = 0
    daily_commit_counts = {}
    
    if client:
        try:
            # 1. Fetch user UUID
            u_res = client.table("users").select("id").eq("firebase_uid", firebase_uid).execute()
            if u_res.data:
                user_id = u_res.data[0]["id"]
                
                # 2. Fetch ALL repositories for this user sorted by last_synced_at (GitHub updated_at) desc
                repos_res = client.table("repositories").select(
                    "id, name, full_name, description, is_private, stars, forks, primary_language, default_branch, status, last_synced_at, created_at"
                ).eq("user_id", user_id).order("last_synced_at", desc=True).execute()
                
                all_repos = repos_res.data or []
                total_repos = len(all_repos)
                recent_repos = all_repos
                
                # Filter starred repos (stars > 0) sorted descending by stars count
                starred_repos = sorted(
                    [r for r in all_repos if r.get("stars", 0) > 0],
                    key=lambda r: r.get("stars", 0),
                    reverse=True
                )
                
                repo_ids = [r["id"] for r in all_repos]
                if repo_ids:
                    # 3. Active branches count
                    try:
                        b_res = client.table("branches").select("id", count="exact").in_("repository_id", repo_ids).execute()
                        active_branches = b_res.count or len(b_res.data or [])
                    except Exception as e:
                        print(f"Error count branches: {e}")
                    
                    # 4. Open PRs count
                    try:
                        pr_res = client.table("pull_requests").select("id", count="exact").in_("repository_id", repo_ids).eq("state", "open").execute()
                        open_prs = pr_res.count or len(pr_res.data or [])
                    except Exception as e:
                        print(f"Error count PRs: {e}")
                    
                    # 5. Failing CI runs count
                    try:
                        wf_res = client.table("workflow_runs").select("id", count="exact").in_("repository_id", repo_ids).eq("status", "failure").execute()
                        failing_workflows = wf_res.count or len(wf_res.data or [])
                    except Exception as e:
                        print(f"Error count workflows: {e}")
                
                # 6. Fetch live GraphQL contribution calendar (exact totalContributions e.g. 249 + daily map)
                access_token = await GitHubSyncService.get_user_access_token(user_id)
                if access_token:
                    contrib_data = await GitHubSyncService.fetch_user_contributions(access_token)
                    total_contributions = contrib_data.get("total_contributions", 0)
                    daily_commit_counts = contrib_data.get("activity_heatmap", {})
                
                # Fallback to Supabase commits table if GraphQL token unavailable
                if not daily_commit_counts and repo_ids:
                    try:
                        commits_res = client.table("commits").select("committed_at").in_("repository_id", repo_ids).execute()
                        for c in (commits_res.data or []):
                            dt_str = c.get("committed_at")
                            if dt_str:
                                date_key = dt_str[:10]
                                daily_commit_counts[date_key] = daily_commit_counts.get(date_key, 0) + 1
                        total_contributions = sum(daily_commit_counts.values())
                    except Exception as e:
                        print(f"Fallback commit count error: {e}")

        except Exception as e:
            print(f"Error fetching dashboard metrics: {e}")

    response_dict = {
        "summary": {
            "total_repositories": total_repos,
            "open_pull_requests": open_prs,
            "failing_ci_runs": failing_workflows,
            "active_branches": active_branches,
            "total_contributions": total_contributions,
            "health_score": 95 if total_repos > 0 else 100
        },
        "recent_repositories": recent_repos,
        "starred_repositories": starred_repos,
        "activity_heatmap": daily_commit_counts
    }
    cache.set(cache_key, response_dict, ttl_seconds=300)
    return response_dict
