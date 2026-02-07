-- ============================================================
-- Grocery templates + checklist items
-- ============================================================

CREATE TABLE public.grocery_stores (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  items jsonb NOT NULL DEFAULT '[]',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.grocery_stores enable row level security;

CREATE POLICY "Users can read own grocery stores"
  ON public.grocery_stores for select
  using (auth.uid() = user_id);

CREATE POLICY "Users can insert own grocery stores"
  ON public.grocery_stores for insert
  with check (auth.uid() = user_id);

CREATE POLICY "Users can update own grocery stores"
  ON public.grocery_stores for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

CREATE POLICY "Users can delete own grocery stores"
  ON public.grocery_stores for delete
  using (auth.uid() = user_id);

ALTER TABLE public.tasks
  ADD COLUMN checklist_items jsonb;
