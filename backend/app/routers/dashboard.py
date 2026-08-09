from typing import Dict, Any
from fastapi import APIRouter, Depends
from app.core.security import verify_firebase_token
from app.core.supabase_client import get_supabase_client

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])

@router.get("")
async def get_dashboard_summary(
    firebase_user: Dict[str, Any] = Depends(verify_firebase_token)
):
    firebase_uid = firebase_user.get("uid")
    client = get_supabase_client()
    
    total_repos = 0
    open_prs = 0
    failing_workflows = 0
    active_branches = 0
    recent_repos = []
    
    if client:
        try:
            # Fetch user UUID first
            u_res = client.table("users").select("id").eq("firebase_uid", firebase_uid).execute()
            if u_res.data:
                user_id = u_res.data[0]["id"]
                
                # Repo count & recent repos
                repos_res = client.table("repositories").select("id, name, full_name, stars, forks, primary_language, status", count="exact").eq("user_id", user_id).order("created_at", desc=True).execute()
                total_repos = repos_res.count or len(repos_res.data or [])
                recent_repos = repos_res.data[:5] if repos_res.data else []
                
                repo_ids = [r["id"] for r in (repos_res.data or [])]
                if repo_ids:
                    # Active branches count
                    b_res = client.table("branches").select("id", count="exact").in_("repository_id", repo_ids).execute()
                    active_branches = b_res.count or len(b_res.data or [])
                    
                    # Open PRs count
                    pr_res = client.table("pull_requests").select("id", count="exact").in_("repository_id", repo_ids).eq("state", "open").execute()
                    open_prs = pr_res.count or len(pr_res.data or [])
                    
                    # Failing CI runs count
                    wf_res = client.table("workflow_runs").select("id", count="exact").in_("repository_id", repo_ids).eq("status", "failure").execute()
                    failing_workflows = wf_res.count or len(wf_res.data or [])
                
        except Exception as e:
            print(f"Error fetching dashboard metrics: {e}")

    return {
        "summary": {
            "total_repositories": total_repos,
            "open_pull_requests": open_prs,
            "failing_ci_runs": failing_workflows,
            "active_branches": active_branches,
            "health_score": 95 if total_repos > 0 else 100
        },
        "recent_repositories": recent_repos,
        "activity_heatmap": [
            {"date": "2026-08-01", "count": 4},
            {"date": "2026-08-02", "count": 7},
            {"date": "2026-08-03", "count": 2},
            {"date": "2026-08-04", "count": 12},
            {"date": "2026-08-05", "count": 8},
            {"date": "2026-08-06", "count": 5},
            {"date": "2026-08-07", "count": 15},
            {"date": "2026-08-08", "count": 9},
            {"date": "2026-08-09", "count": 11}
        ]
    }
