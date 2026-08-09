from typing import Dict, Any, List, Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from app.core.security import verify_firebase_token
from app.core.supabase_client import get_supabase_client

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
    client = get_supabase_client()
    projects = []
    
    if client:
        try:
            u_res = client.table("users").select("id").eq("firebase_uid", firebase_uid).execute()
            if u_res.data:
                user_id = u_res.data[0]["id"]
                query = client.table("repositories").select("*").eq("user_id", user_id)
                if category:
                    query = query.eq("category", category)
                if status:
                    query = query.eq("status", status)
                res = query.execute()
                projects = res.data or []
        except Exception as e:
            print(f"Error listing projects: {e}")
            
    return {"projects": projects}

@router.get("/{project_id}")
async def get_project_details(
    project_id: str,
    firebase_user: Dict[str, Any] = Depends(verify_firebase_token)
):
    client = get_supabase_client()
    project = None
    notes = []
    goals = []
    
    if client:
        try:
            p_res = client.table("repositories").select("*").eq("id", project_id).execute()
            if p_res.data:
                project = p_res.data[0]
                notes_res = client.table("project_notes").select("*").eq("repository_id", project_id).execute()
                notes = notes_res.data or []
                goals_res = client.table("project_goals").select("*").eq("repository_id", project_id).execute()
                goals = goals_res.data or []
        except Exception as e:
            print(f"Error fetching project detail: {e}")
            
    if not project:
        # Return fallback mock if not found in db yet
        return {
            "id": project_id,
            "name": "Project Tracker",
            "full_name": "developer/project-tracker",
            "description": "Unified GitHub dashboard & native developer planner",
            "stars": 42,
            "forks": 5,
            "primary_language": "Dart",
            "default_branch": "main",
            "status": "active",
            "notes": notes,
            "goals": goals
        }

    project["notes"] = notes
    project["goals"] = goals
    return project
