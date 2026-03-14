create table if not exists public.look_profiles (
  workspace_id text primary key,
  id uuid not null,
  name text not null default '',
  stage_raw text not null,
  city_raw text not null,
  language_raw text not null,
  created_at timestamptz not null,
  updated_at timestamptz not null
);

create table if not exists public.look_questions (
  workspace_id text not null,
  id uuid not null,
  question text not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  category_raw text not null,
  ai_summary text not null,
  recommendation text not null,
  safety_note text not null,
  escalate_to_human boolean not null default false,
  resolved boolean not null default false,
  user_notes text not null default '',
  primary key (workspace_id, id)
);

create table if not exists public.look_trials (
  workspace_id text not null,
  id uuid not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  rating integer not null,
  what_worked text not null,
  friction text not null,
  next_improvement text not null,
  primary key (workspace_id, id)
);

create table if not exists public.look_health_logs (
  workspace_id text not null,
  day_key text not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  medication_confirmed_at timestamptz,
  checkin_completed_at timestamptz,
  checkin_status_raw text,
  primary key (workspace_id, day_key)
);

alter table public.look_profiles enable row level security;
alter table public.look_questions enable row level security;
alter table public.look_trials enable row level security;
alter table public.look_health_logs enable row level security;

drop policy if exists "anon full access look_profiles" on public.look_profiles;
drop policy if exists "anon full access look_questions" on public.look_questions;
drop policy if exists "anon full access look_trials" on public.look_trials;
drop policy if exists "anon full access look_health_logs" on public.look_health_logs;

create policy "anon full access look_profiles"
on public.look_profiles
for all
to anon
using (true)
with check (true);

create policy "anon full access look_questions"
on public.look_questions
for all
to anon
using (true)
with check (true);

create policy "anon full access look_trials"
on public.look_trials
for all
to anon
using (true)
with check (true);

create policy "anon full access look_health_logs"
on public.look_health_logs
for all
to anon
using (true)
with check (true);
