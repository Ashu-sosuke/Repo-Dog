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
    async def fetch_repo_readme(access_token: str, owner: str, repo_name: str) -> Optional[str]:
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/vnd.github.v3.raw",
            "User-Agent": "Repo-Dog-App"
        }
        try:
            async with httpx.AsyncClient(timeout=10.0) as http_client:
                resp = await http_client.get(
                    f"{GITHUB_API_BASE}/repos/{owner}/{repo_name}/readme",
                    headers=headers
                )
                if resp.status_code == 200:
                    return resp.text
        except Exception as e:
            print(f"Error fetching README for {owner}/{repo_name}: {e}")
        return None

    @staticmethod
    async def fetch_user_profile_full(access_token: str) -> Dict[str, Any]:
        """Fetch GitHub user profile metadata + Profile README."""
        headers_json = {
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/vnd.github.v3+json",
            "User-Agent": "Repo-Dog-App"
        }
        profile_data = {}
        try:
            async with httpx.AsyncClient(timeout=10.0) as http_client:
                u_resp = await http_client.get(f"{GITHUB_API_BASE}/user", headers=headers_json)
                if u_resp.status_code == 200:
                    profile_data = u_resp.json()
                    username = profile_data.get("login")
                    if username:
                        readme_text = await GitHubSyncService.fetch_repo_readme(access_token, username, username)
                        profile_data["profile_readme"] = readme_text
        except Exception as e:
            print(f"Error fetching full user profile: {e}")
        return profile_data

    @staticmethod
    async def fetch_user_contributions(access_token: str) -> Dict[str, Any]:
        """Fetch real contribution calendar from GitHub GraphQL API."""
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/vnd.github.v3+json",
            "User-Agent": "Repo-Dog-App"
        }
        query = """
        query {
          viewer {
            contributionsCollection {
              contributionCalendar {
                totalContributions
                weeks {
                  contributionDays {
                    date
                    contributionCount
                  }
                }
              }
            }
          }
        }
        """
        try:
            async with httpx.AsyncClient(timeout=15.0) as http_client:
                gql_resp = await http_client.post(
                    f"{GITHUB_API_BASE}/graphql",
                    json={"query": query},
                    headers=headers
                )
                if gql_resp.status_code == 200:
                    cal = gql_resp.json().get("data", {}).get("viewer", {}).get("contributionsCollection", {}).get("contributionCalendar", {})
                    total = cal.get("totalContributions", 0)
                    daily_counts = {}
                    for week in cal.get("weeks", []):
                        for day in week.get("contributionDays", []):
                            date_str = day.get("date")
                            count = day.get("contributionCount", 0)
                            if date_str:
                                daily_counts[date_str] = count
                    return {
                        "total_contributions": total,
                        "activity_heatmap": daily_counts
                    }
        except Exception as e:
            print(f"Error fetching GraphQL contributions: {e}")
        return {"total_contributions": 0, "activity_heatmap": {}}

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
            "User-Agent": "Repo-Dog-App"
        }

        async with httpx.AsyncClient(timeout=30.0) as http_client:
            # 1. Fetch Repositories sorted by updated_at descending
            print(f"[Sync] Requesting GET {GITHUB_API_BASE}/user/repos?sort=updated&direction=desc&per_page=100")
            all_repos = []
            page = 1
            while True:
                repos_resp = await http_client.get(
                    f"{GITHUB_API_BASE}/user/repos?sort=updated&direction=desc&per_page=100&page={page}",
                    headers=headers
                )
                if repos_resp.status_code != 200:
                    print(f"[Sync Error] GitHub API error: {repos_resp.status_code} {repos_resp.text}")
                    break

                page_repos = repos_resp.json()
                if not page_repos or not isinstance(page_repos, list):
                    break

                all_repos.extend(page_repos)
                if len(page_repos) < 100:
                    break
                page += 1

            print(f"[Sync] Received total {len(all_repos)} repositories from GitHub API!")
            client = get_supabase_client()
            synced_count = 0

            for r in all_repos:
                repo_id = r["id"]
                # Store GitHub's updated_at in last_synced_at timestamp so order is preserved in Supabase
                updated_at_str = r.get("updated_at") or r.get("pushed_at") or datetime.now(timezone.utc).isoformat()
                
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
                    "last_synced_at": updated_at_str
                }

                if client:
                    try:
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
                "message": f"Successfully synced {synced_count} repositories and commit history from GitHub.",
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
                        client.table("branches").upsert(branch_data, on_conflict="repository_id,name").execute()
        except Exception as e:
            print(f"Error syncing branches for {owner}/{repo}: {e}")

    @staticmethod
    async def _sync_repo_commits(http_client: httpx.AsyncClient, headers: dict, db_repo_id: str, owner: str, repo: str):
        try:
            resp = await http_client.get(f"{GITHUB_API_BASE}/repos/{owner}/{repo}/commits?per_page=100", headers=headers)
            if resp.status_code == 200:
                commits = resp.json()
                client = get_supabase_client()
                for c in commits:
                    if not isinstance(c, dict):
                        continue
                    sha = c.get("sha")
                    if not sha:
                        continue
                    commit_info = c.get("commit", {})
                    c_data = {
                        "repository_id": db_repo_id,
                        "sha": sha,
                        "message": commit_info.get("message"),
                        "author_name": commit_info.get("author", {}).get("name"),
                        "committed_at": commit_info.get("committer", {}).get("date") or commit_info.get("author", {}).get("date")
                    }
                    if client:
                        client.table("commits").upsert(c_data, on_conflict="repository_id,sha").execute()
        except Exception as e:
            print(f"Error syncing commits for {owner}/{repo}: {e}")

    @staticmethod
    async def _sync_repo_issues(http_client: httpx.AsyncClient, headers: dict, db_repo_id: str, owner: str, repo: str):
        try:
            resp = await http_client.get(f"{GITHUB_API_BASE}/repos/{owner}/{repo}/issues?state=all&per_page=30", headers=headers)
            if resp.status_code == 200:
                issues = resp.json()
                client = get_supabase_client()
                for iss in issues:
                    if "pull_request" in iss:
                        continue
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
            resp = await http_client.get(f"{GITHUB_API_BASE}/repos/{owner}/{repo}/pulls?state=all&per_page=30", headers=headers)
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
            resp = await http_client.get(f"{GITHUB_API_BASE}/repos/{owner}/{repo}/actions/runs?per_page=20", headers=headers)
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
