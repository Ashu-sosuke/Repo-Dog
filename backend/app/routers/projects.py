from typing import Dict, Any, List, Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from app.core.security import verify_firebase_token
from app.core.supabase_client import get_supabase_client
from app.services.github_service import GitHubSyncService
from app.core.cache import cache

router = APIRouter(prefix="/projects", tags=["Projects"])

class NoteCreateRequest(BaseModel):
    content: str

class GoalCreateRequest(BaseModel):
    title: str

@router.get("")
async def list_user_projects(
    category: Optional[str] = None,
    status: Optional[str] = None,
    firebase_user: Dict[str, Any] = Depends(verify_firebase_token)
):
    firebase_uid = firebase_user.get("uid")
    cache_key = f"projects_list:{firebase_uid}:{category}:{status}"
    
    cached = cache.get(cache_key)
    if cached:
        return cached

    client = get_supabase_client()
    projects = []
    
    if client:
        try:
            u_res = client.table("users").select("id").eq("firebase_uid", firebase_uid).execute()
            if u_res.data:
                user_id = u_res.data[0]["id"]
                query = client.table("repositories").select("*").eq("user_id", user_id).order("last_synced_at", desc=True)
                if category:
                    query = query.eq("category", category)
                if status:
                    query = query.eq("status", status)
                res = query.execute()
                projects = res.data or []
        except Exception as e:
            print(f"Error listing projects: {e}")
            
    res_dict = {"projects": projects}
    cache.set(cache_key, res_dict, ttl_seconds=300)
    return res_dict

@router.get("/{project_id}")
async def get_project_details(
    project_id: str,
    firebase_user: Dict[str, Any] = Depends(verify_firebase_token)
):
    cache_key = f"project_detail:{project_id}"
    cached = cache.get(cache_key)
    if cached:
        return cached

    client = get_supabase_client()
    project = None
    notes = []
    goals = []
    branches = []
    commits = []
    pull_requests = []
    workflow_runs = []
    readme_content = None
    
    if client:
        try:
            p_res = client.table("repositories").select("*").eq("id", project_id).execute()
            if p_res.data:
                project = p_res.data[0]
                user_id = project.get("user_id")
                full_name = project.get("full_name", "")
                
                # Fetch notes & goals
                try:
                    notes_res = client.table("project_notes").select("*").eq("repository_id", project_id).execute()
                    notes = notes_res.data or []
                except Exception as e:
                    print(f"Error fetching notes: {e}")

                try:
                    goals_res = client.table("project_goals").select("*").eq("repository_id", project_id).execute()
                    goals = goals_res.data or []
                except Exception as e:
                    print(f"Error fetching goals: {e}")

                # Fetch branches, commits, PRs, workflow runs
                try:
                    b_res = client.table("branches").select("*").eq("repository_id", project_id).execute()
                    raw_branches = b_res.data or []
                    unique_b = {}
                    for b in raw_branches:
                        b_name = b.get("name")
                        if b_name and (b_name not in unique_b or b.get("is_default")):
                            unique_b[b_name] = b
                    branches = list(unique_b.values())
                    branches.sort(key=lambda x: (not x.get("is_default", False), x.get("name", "")))
                except Exception as e:
                    print(f"Error fetching branches: {e}")

                try:
                    c_res = client.table("commits").select("*").eq("repository_id", project_id).order("committed_at", desc=True).limit(50).execute()
                    commits = c_res.data or []
                except Exception as e:
                    print(f"Error fetching commits: {e}")

                try:
                    pr_res = client.table("pull_requests").select("*").eq("repository_id", project_id).execute()
                    pull_requests = pr_res.data or []
                except Exception as e:
                    print(f"Error fetching pull requests: {e}")

                try:
                    wf_res = client.table("workflow_runs").select("*").eq("repository_id", project_id).execute()
                    workflow_runs = wf_res.data or []
                except Exception as e:
                    print(f"Error fetching workflow runs: {e}")

                # Fetch live README from GitHub API
                if full_name and "/" in full_name and user_id:
                    try:
                        owner, repo_name = full_name.split("/", 1)
                        access_token = await GitHubSyncService.get_user_access_token(user_id)
                        if access_token:
                            readme_content = await GitHubSyncService.fetch_repo_readme(access_token, owner, repo_name)
                    except Exception as e:
                        print(f"Error fetching README for {full_name}: {e}")

        except Exception as e:
            print(f"Error fetching project detail: {e}")
            
    if not project:
        result = {
            "id": project_id,
            "name": "Repository",
            "full_name": "developer/repository",
            "description": "Synced GitHub repository",
            "stars": 0,
            "forks": 0,
            "primary_language": "Code",
            "default_branch": "main",
            "status": "active",
            "notes": notes,
            "goals": goals,
            "branches": branches,
            "commits": commits,
            "pull_requests": pull_requests,
            "workflow_runs": workflow_runs,
            "readme_content": readme_content
        }
        cache.set(cache_key, result, ttl_seconds=300)
        return result

    project["notes"] = notes
    project["goals"] = goals
    project["branches"] = branches
    project["commits"] = commits
    project["pull_requests"] = pull_requests
    project["workflow_runs"] = workflow_runs
    project["readme_content"] = readme_content
    
    cache.set(cache_key, project, ttl_seconds=300)
    return project
