-- ============================================================
-- Docket Database Schema
-- Run this in Supabase SQL Editor (supabase.com → your project → SQL Editor)
-- ============================================================

-- Enable UUID generation
create extension if not exists "uuid-ossp";

-- ============================================================
-- Priority enum matching Swift Priority (0=low, 1=medium, 2=high)
-- ============================================================
create type priority_level as enum ('low', 'medium', 'high');

-- ============================================================
-- Tasks table (mirrors SwiftData Task model exactly)
-- ============================================================
create table public.tasks (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) > 0),
  is_completed boolean not null default false,
  created_at timestamptz not null default now(),
  due_date timestamptz,
  priority priority_level not null default 'medium',
  category text,
  notes text,
  completed_at timestamptz,
  updated_at timestamptz not null default now()
);

-- Indexes for common queries
create index idx_tasks_user_id on public.tasks(user_id);
create index idx_tasks_user_completed on public.tasks(user_id, is_completed);
create index idx_tasks_user_due_date on public.tasks(user_id, due_date) where due_date is not null;
create index idx_tasks_user_priority on public.tasks(user_id, priority);

-- ============================================================
-- Auto-update updated_at on row change
-- ============================================================
create or replace function public.update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger tasks_updated_at
  before update on public.tasks
  for each row
  execute function public.update_updated_at();

-- ============================================================
-- Row Level Security (users can only access their own tasks)
-- ============================================================
alter table public.tasks enable row level security;

create policy "Users can read own tasks"
  on public.tasks for select
  using (auth.uid() = user_id);

create policy "Users can insert own tasks"
  on public.tasks for insert
  with check (auth.uid() = user_id);

create policy "Users can update own tasks"
  on public.tasks for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete own tasks"
  on public.tasks for delete
  using (auth.uid() = user_id);

-- ============================================================
-- Voice parsing logs (for analytics + debugging)
-- ============================================================
create table public.voice_parse_logs (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  transcribed_text text not null,
  parsed_tasks jsonb not null default '[]',
  model_used text,
  latency_ms integer,
  tasks_accepted integer default 0,
  tasks_rejected integer default 0,
  created_at timestamptz not null default now()
);

create index idx_voice_logs_user on public.voice_parse_logs(user_id);

alter table public.voice_parse_logs enable row level security;

create policy "Users can read own voice logs"
  on public.voice_parse_logs for select
  using (auth.uid() = user_id);

create policy "Users can insert own voice logs"
  on public.voice_parse_logs for insert
  with check (auth.uid() = user_id);
