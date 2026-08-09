-- 20260809000000_initial_schema.sql
-- Initial database schema for Project Tracker

-- Enable uuid extension
create extension if not exists "uuid-ossp";

-- Users (mirrors Firebase Auth users; firebase_uid is the join key everywhere)
create table if not exists users (
  id uuid primary key default gen_random_uuid(),
  firebase_uid text unique not null,
  github_username text,
  email text,
  display_name text,
  avatar_url text,
  created_at timestamptz default now()
);

-- Encrypted GitHub OAuth tokens, one row per user
create table if not exists github_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id) on delete cascade,
  github_user_id bigint,
  access_token_encrypted text not null,
  token_created_at timestamptz default now(),
  scopes text[],
  is_valid boolean default true
);

-- Repositories synced from GitHub
create table if not exists repositories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id) on delete cascade,
  github_repo_id bigint not null,
  name text not null,
  full_name text not null,
  description text,
  is_private boolean default false,
  stars int default 0,
  forks int default 0,
  primary_language text,
  default_branch text,
  status text default 'active', -- active | inactive | archived
  category text, -- portfolio | experiment | hackathon | completed etc
  tags text[],
  last_synced_at timestamptz,
  created_at timestamptz default now(),
  unique(user_id, github_repo_id)
);

-- Branches
create table if not exists branches (
  id uuid primary key default gen_random_uuid(),
  repository_id uuid references repositories(id) on delete cascade,
  name text not null,
  is_default boolean default false,
  ahead_by int default 0,
  behind_by int default 0,
  is_stale boolean default false,
  last_commit_at timestamptz,
  updated_at timestamptz default now()
);

-- Commits
create table if not exists commits (
  id uuid primary key default gen_random_uuid(),
  repository_id uuid references repositories(id) on delete cascade,
  branch_name text,
  sha text not null,
  message text,
  author_name text,
  committed_at timestamptz,
  unique(repository_id, sha)
);

-- Issues
create table if not exists issues (
  id uuid primary key default gen_random_uuid(),
  repository_id uuid references repositories(id) on delete cascade,
  github_issue_number int,
  title text,
  state text, -- open | closed
  labels text[],
  assignee text,
  created_at timestamptz,
  closed_at timestamptz
);

-- Pull Requests
create table if not exists pull_requests (
  id uuid primary key default gen_random_uuid(),
  repository_id uuid references repositories(id) on delete cascade,
  github_pr_number int,
  title text,
  state text, -- open | merged | closed
  is_draft boolean default false,
  has_conflicts boolean default false,
  review_status text, -- awaiting_review | approved | changes_requested
  author text,
  created_at timestamptz,
  merged_at timestamptz
);

-- Workflow Runs
create table if not exists workflow_runs (
  id uuid primary key default gen_random_uuid(),
  repository_id uuid references repositories(id) on delete cascade,
  workflow_name text,
  status text, -- success | failure | in_progress
  run_number int,
  started_at timestamptz,
  finished_at timestamptz
);

-- App-native data (never synced to GitHub)
create table if not exists project_notes (
  id uuid primary key default gen_random_uuid(),
  repository_id uuid references repositories(id) on delete cascade,
  content text,
  updated_at timestamptz default now()
);

create table if not exists project_goals (
  id uuid primary key default gen_random_uuid(),
  repository_id uuid references repositories(id) on delete cascade,
  title text not null,
  is_complete boolean default false,
  position int default 0,
  created_at timestamptz default now()
);

create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id) on delete cascade,
  type text, -- ci_failed | stale_branch | pr_awaiting_review | project_inactive
  repository_id uuid references repositories(id) on delete cascade,
  message text,
  is_read boolean default false,
  created_at timestamptz default now()
);

-- Performance Indexes
create index if not exists idx_repositories_user_id on repositories(user_id);
create index if not exists idx_branches_repository_id on branches(repository_id);
create index if not exists idx_commits_repository_id on commits(repository_id);
create index if not exists idx_issues_repository_id on issues(repository_id);
create index if not exists idx_pull_requests_repository_id on pull_requests(repository_id);
create index if not exists idx_notifications_user_id_is_read on notifications(user_id, is_read);

-- Row Level Security (RLS) Setup
alter table users enable row level security;
alter table github_accounts enable row level security;
alter table repositories enable row level security;
alter table branches enable row level security;
alter table commits enable row level security;
alter table issues enable row level security;
alter table pull_requests enable row level security;
alter table workflow_runs enable row level security;
alter table project_notes enable row level security;
alter table project_goals enable row level security;
alter table notifications enable row level security;

-- Basic RLS Policies using Firebase UID claim or fallback
create policy "Users can view own user record" on users
  for select using (firebase_uid = auth.jwt() ->> 'sub' or firebase_uid = (auth.jwt() -> 'claims') ->> 'user_id');

create policy "Users can view own repositories" on repositories
  for select using (user_id in (select id from users where firebase_uid = auth.jwt() ->> 'sub'));

create policy "Users can view own notifications" on notifications
  for select using (user_id in (select id from users where firebase_uid = auth.jwt() ->> 'sub'));
