-- ============================================================
-- Task Sharing v2: Auto-resolve recipients, push notifications, collaboration
-- ============================================================

-- ============================================================
-- Device tokens for push notifications
-- ============================================================

CREATE TABLE IF NOT EXISTS public.device_tokens (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token text NOT NULL,
  platform text NOT NULL DEFAULT 'ios',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, token)
);

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own tokens"
  ON public.device_tokens FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- Auto-resolve share recipient on INSERT
-- ============================================================

CREATE OR REPLACE FUNCTION resolve_share_recipient()
RETURNS TRIGGER AS $$
BEGIN
  -- Try to find recipient by email in user_profiles or auth.users
  SELECT id INTO NEW.shared_with_id
  FROM public.user_profiles
  WHERE email = NEW.shared_with_email
     OR id IN (
       SELECT id FROM auth.users 
       WHERE email = NEW.shared_with_email
     )
  LIMIT 1;
  
  -- If found, auto-accept the share
  IF NEW.shared_with_id IS NOT NULL THEN
    NEW.status := 'accepted';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER resolve_share_recipient_trigger
  BEFORE INSERT ON public.task_shares
  FOR EACH ROW
  EXECUTE FUNCTION resolve_share_recipient();

-- ============================================================
-- Auto-resolve pending shares when new user signs up
-- ============================================================

CREATE OR REPLACE FUNCTION resolve_pending_shares_for_new_user()
RETURNS TRIGGER AS $$
DECLARE
  user_email text;
BEGIN
  -- Get the email from auth.users
  SELECT email INTO user_email
  FROM auth.users
  WHERE id = NEW.id;
  
  -- Resolve any pending shares matching this email
  UPDATE public.task_shares
  SET shared_with_id = NEW.id, status = 'accepted'
  WHERE (shared_with_email = NEW.email OR shared_with_email = user_email)
    AND shared_with_id IS NULL
    AND status = 'pending';
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER resolve_pending_shares_on_profile_create
  AFTER INSERT ON public.user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION resolve_pending_shares_for_new_user();

-- ============================================================
-- RLS Policy Fixes
-- ============================================================

-- Recipients can UPDATE shared tasks (collaboration)
CREATE POLICY "Recipients can update shared tasks"
  ON public.tasks FOR UPDATE
  USING (
    id IN (
      SELECT task_id
      FROM public.task_shares
      WHERE shared_with_id = auth.uid() AND status = 'accepted'
    )
  )
  WITH CHECK (
    id IN (
      SELECT task_id
      FROM public.task_shares
      WHERE shared_with_id = auth.uid() AND status = 'accepted'
    )
  );

-- Cross-user profile lookup: users can see profiles of people they share tasks with
CREATE POLICY "Users can see sharer profiles"
  ON public.user_profiles FOR SELECT
  USING (
    id IN (
      SELECT DISTINCT owner_id
      FROM public.task_shares
      WHERE shared_with_id = auth.uid() AND status = 'accepted'
    )
    OR
    id IN (
      SELECT DISTINCT shared_with_id
      FROM public.task_shares
      WHERE owner_id = auth.uid() AND status = 'accepted'
    )
  );

-- Recipients can remove themselves from a share
CREATE POLICY "Recipients can remove themselves from share"
  ON public.task_shares FOR DELETE
  USING (auth.uid() = shared_with_id);

-- ============================================================
-- Drop unused invitations table
-- ============================================================

DROP TABLE IF EXISTS public.invitations CASCADE;
