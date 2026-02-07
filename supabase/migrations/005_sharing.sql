-- ============================================================
-- Task sharing + invitations + saved contacts
-- ============================================================

CREATE TABLE public.contacts (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  contact_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  contact_email text NOT NULL,
  contact_name text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, contact_email)
);

ALTER TABLE public.contacts enable row level security;

CREATE POLICY "Users can read own contacts"
  ON public.contacts for select
  using (auth.uid() = user_id);

CREATE POLICY "Users can insert own contacts"
  ON public.contacts for insert
  with check (auth.uid() = user_id);

CREATE POLICY "Users can update own contacts"
  ON public.contacts for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

CREATE POLICY "Users can delete own contacts"
  ON public.contacts for delete
  using (auth.uid() = user_id);

CREATE TABLE public.task_shares (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  task_id uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  shared_with_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  shared_with_email text,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.task_shares enable row level security;

CREATE POLICY "Owners can manage shares"
  ON public.task_shares for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

CREATE POLICY "Recipients can read shares"
  ON public.task_shares for select
  using (auth.uid() = shared_with_id);

CREATE TABLE public.invitations (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  inviter_id uuid NOT NULL REFERENCES auth.users(id),
  email text NOT NULL,
  task_id uuid REFERENCES public.tasks(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.invitations enable row level security;

CREATE POLICY "Inviters can manage invitations"
  ON public.invitations for all
  using (auth.uid() = inviter_id)
  with check (auth.uid() = inviter_id);

-- Shared task access
CREATE POLICY "Users can read shared tasks"
  ON public.tasks FOR SELECT
  USING (
    id IN (
      SELECT task_id
      FROM public.task_shares
      WHERE shared_with_id = auth.uid() AND status = 'accepted'
    )
  );
