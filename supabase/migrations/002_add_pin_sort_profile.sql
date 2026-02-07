-- ============================================================
-- Add pin + sort ordering + user profiles
-- ============================================================

ALTER TABLE public.tasks
  ADD COLUMN is_pinned boolean NOT NULL DEFAULT false;

ALTER TABLE public.tasks
  ADD COLUMN sort_order integer NOT NULL DEFAULT 0;

-- ============================================================
-- User profiles for display names / avatars
-- ============================================================

CREATE TABLE public.user_profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text,
  email text,
  avatar_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_profiles enable row level security;

CREATE POLICY "Users can read own profile"
  ON public.user_profiles for select
  using (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON public.user_profiles for insert
  with check (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.user_profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);
