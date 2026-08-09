from typing import Dict, Any, List, Optional
import httpx
from datetime import datetime, timezone, timedelta
from app.core.supabase_client import get_supabase_client
from app.core.security import decrypt_token

GITHUB_API_BASE = "https://api.github.com"

class GitHubSyncService:
    @staticmethod
    async def get_user_access_token(user_db_id: str) -> Optional[str]:
        client = get_supabase_client()
        if not client:
            return None
        try:
            res = client.table("github_accounts").select("access_token_encrypted").eq("user_id", user_db_id).execute()
            if res.data and len(res.data) > 0:
                encrypted = res.data[0]["access_token_encrypted"]
                return decrypt_token(encrypted)
        except Exception as e:
            print(f"Error decrypting user token: {e}")
        return None

    @staticmethod
    async def sync_all_user_repos(user_db_id: str) -> Dict[str, Any]:
        print(f"[Sync] Starting GitHub sync for user_db_id={user_db_id}")
        access_token = await GitHubSyncService.get_user_access_token(user_db_id)
        if not access_token:
            print(f"[Sync Error] No access token found in database for user {user_db_id}")
            return {"status": "error", "message": "No valid GitHub access token found for user."}

        print(f"[Sync] Access token retrieved successfully (starts with {access_token[:6]}...)")
        
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/vnd.github.v3+json",
            "User-Agent": "Project-Tracker-App"
        }

        async with httpx.AsyncClient(timeout=20.0) as http_client:
            # 1. Fetch Repositories
            print(f"[Sync] Requesting GET {GITHUB_API_BASE}/user/repos")
            repos_resp = await http_client.get(f"{GITHUB_API_BASE}/user/repos?sort=updated&per_page=30", headers=headers)
            print(f"[Sync] GitHub API HTTP status: {repos_resp.status_code}")
            if repos_resp.status_code != 200:
                print(f"[Sync Error] GitHub API response: {repos_resp.text}")
                return {"status": "error", "message": f"GitHub API error: {repos_resp.status_code} {repos_resp.text}"}

            repos = repos_resp.json()
            print(f"[Sync] Received {len(repos)} repositories from GitHub API!")
            client = get_supabase_client()
            synced_count = 0

            for r in repos:
                repo_id = r["id"]
                repo_data = {
                    "user_id": user_db_id,
                    "github_repo_id": repo_id,
                    "name": r["name"],
                    "full_name": r["full_name"],
                    "description": r.get("description"),
                    "is_private": r.get("private", False),
                    "stars": r.get("stargazers_count", 0),
                    "forks": r.get("forks_count", 0),
                    "primary_language": r.get("language") or "Code",
                    "default_branch": r.get("default_branch", "main"),
                    "status": "active",
                    "last_synced_at": datetime.now(timezone.utc).isoformat()
                }

                if client:
                    try:
                        # Upsert repo
                        upsert_res = client.table("repositories").upsert(
                            repo_data,
                            on_conflict="user_id,github_repo_id"
                        ).execute()

                        if upsert_res.data:
                            db_repo_id = upsert_res.data[0]["id"]
                            owner = r["owner"]["login"]
                            repo_name = r["name"]

                            # Sync details for this repo
                            await GitHubSyncService._sync_repo_branches(http_client, headers, db_repo_id, owner, repo_name, r.get("default_branch", "main"))
                            await GitHubSyncService._sync_repo_commits(http_client, headers, db_repo_id, owner, repo_name)
                            await GitHubSyncService._sync_repo_issues(http_client, headers, db_repo_id, owner, repo_name)
                            await GitHubSyncService._sync_repo_pull_requests(http_client, headers, db_repo_id, owner, repo_name)
                            await GitHubSyncService._sync_repo_workflows(http_client, headers, db_repo_id, owner, repo_name)
                            synced_count += 1
                    except Exception as e:
                        print(f"Error syncing repo {r['full_name']}: {e}")

            return {
                "status": "success",
                "message": f"Successfully synced {synced_count} repositories and details from GitHub.",
                "repos_synced": synced_count
            }

    @staticmethod
    async def _sync_repo_branches(http_client: httpx.AsyncClient, headers: dict, db_repo_id: str, owner: str, repo: str, default_branch: str):
        try:
            resp = await http_client.get(f"{GITHUB_API_BASE}/repos/{owner}/{repo}/branches", headers=headers)
            if resp.status_code == 200:
                branches = resp.json()
                client = get_supabase_client()
                for b in branches:
                    b_name = b["name"]
                    is_def = (b_name == default_branch)
                    
                    # Check commit date for stale calculation
                    last_commit_at = None
                    is_stale = False
                    if "commit" in b and "url" in b["commit"]:
                        c_resp = await http_client.get(b["commit"]["url"], headers=headers)
                        if c_resp.status_code == 200:
                            c_data = c_resp.json()
                            commit_date_str = c_data.get("commit", {}).get("committer", {}).get("date")
                            if commit_date_str:
                                last_commit_at = commit_date_str
                                dt = datetime.fromisoformat(commit_date_str.replace("Z", "+00:00"))
                                if datetime.now(timezone.utc) - dt > timedelta(days=30):
                                    is_stale = True

                    branch_data = {
                        "repository_id": db_repo_id,
                        "name": b_name,
                        "is_default": is_def,
                        "is_stale": is_stale,
                        "last_commit_at": last_commit_at,
                        "updated_at": datetime.now(timezone.utc).isoformat()
                    }
                    if client:
                        client.table("branches").upsert(branch_data).execute()
        except Exception as e:
            print(f"Error syncing branches for {owner}/{repo}: {e}")

    @staticmethod
    async def _sync_repo_commits(http_client: httpx.AsyncClient, headers: dict, db_repo_id: str, owner: str, repo: str):
        try:
            resp = await http_client.get(f"{GITHUB_API_BASE}/repos/{owner}/{repo}/commits?per_page=15", headers=headers)
            if resp.status_code == 200:
                commits = resp.json()
                client = get_supabase_client()
                for c in commits:
                    sha = c["sha"]
                    commit_info = c.get("commit", {})
                    c_data = {
                        "repository_id": db_repo_id,
                        "sha": sha,
                        "message": commit_info.get("message"),
                        "author_name": commit_info.get("author", {}).get("name"),
                        "committed_at": commit_info.get("committer", {}).get("date")
                    }
                    if client:
                        client.table("commits").upsert(c_data, on_conflict="repository_id,sha").execute()
        except Exception as e:
            print(f"Error syncing commits for {owner}/{repo}: {e}")

    @staticmethod
    async def _sync_repo_issues(http_client: httpx.AsyncClient, headers: dict, db_repo_id: str, owner: str, repo: str):
        try:
            resp = await http_client.get(f"{GITHUB_API_BASE}/repos/{owner}/{repo}/issues?state=all&per_page=15", headers=headers)
            if resp.status_code == 200:
                issues = resp.json()
                client = get_supabase_client()
                for iss in issues:
                    if "pull_request" in iss:
                        continue # PRs handled separately
                    labels = [l["name"] for l in iss.get("labels", []) if isinstance(l, dict)]
                    iss_data = {
                        "repository_id": db_repo_id,
                        "github_issue_number": iss["number"],
                        "title": iss["title"],
                        "state": iss["state"],
                        "labels": labels,
                        "assignee": iss.get("assignee", {}).get("login") if iss.get("assignee") else None,
                        "created_at": iss.get("created_at"),
                        "closed_at": iss.get("closed_at")
                    }
                    if client:
                        client.table("issues").upsert(iss_data).execute()
        except Exception as e:
            print(f"Error syncing issues for {owner}/{repo}: {e}")

    @staticmethod
    async def _sync_repo_pull_requests(http_client: httpx.AsyncClient, headers: dict, db_repo_id: str, owner: str, repo: str):
        try:
            resp = await http_client.get(f"{GITHUB_API_BASE}/repos/{owner}/{repo}/pulls?state=all&per_page=15", headers=headers)
            if resp.status_code == 200:
                prs = resp.json()
                client = get_supabase_client()
                for pr in prs:
                    pr_data = {
                        "repository_id": db_repo_id,
                        "github_pr_number": pr["number"],
                        "title": pr["title"],
                        "state": pr["state"],
                        "is_draft": pr.get("draft", False),
                        "author": pr.get("user", {}).get("login"),
                        "created_at": pr.get("created_at"),
                        "merged_at": pr.get("merged_at")
                    }
                    if client:
                        client.table("pull_requests").upsert(pr_data).execute()
        except Exception as e:
            print(f"Error syncing PRs for {owner}/{repo}: {e}")

    @staticmethod
    async def _sync_repo_workflows(http_client: httpx.AsyncClient, headers: dict, db_repo_id: str, owner: str, repo: str):
        try:
            resp = await http_client.get(f"{GITHUB_API_BASE}/repos/{owner}/{repo}/actions/runs?per_page=10", headers=headers)
            if resp.status_code == 200:
                runs = resp.json().get("workflow_runs", [])
                client = get_supabase_client()
                for run in runs:
                    w_data = {
                        "repository_id": db_repo_id,
                        "workflow_name": run.get("name"),
                        "status": run.get("conclusion") or run.get("status"),
                        "run_number": run.get("run_number"),
                        "started_at": run.get("run_started_at"),
                        "finished_at": run.get("updated_at")
                    }
                    if client:
                        client.table("workflow_runs").upsert(w_data).execute()
        except Exception as e:
            print(f"Error syncing workflow runs for {owner}/{repo}: {e}")
