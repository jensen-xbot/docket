-- ============================================================
-- Ingredient library for autocomplete
-- ============================================================

CREATE TABLE public.ingredients (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  display_name text NOT NULL,
  use_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.ingredients enable row level security;

CREATE POLICY "Users can read own ingredients"
  ON public.ingredients for select
  using (auth.uid() = user_id);

CREATE POLICY "Users can insert own ingredients"
  ON public.ingredients for insert
  with check (auth.uid() = user_id);

CREATE POLICY "Users can update own ingredients"
  ON public.ingredients for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

CREATE POLICY "Users can delete own ingredients"
  ON public.ingredients for delete
  using (auth.uid() = user_id);
