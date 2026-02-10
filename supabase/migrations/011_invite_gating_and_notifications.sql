-- ============================================================
-- Sharing System V2: Invite gating + notifications
-- ============================================================
-- Phase 2: Replace auto-accept with invite-gated model
-- Phase 3: Notifications table for inbox/bell
-- ============================================================

-- ============================================================
-- Phase 2: Invite gating — resolve recipient only, no auto-accept
-- ============================================================

CREATE OR REPLACE FUNCTION resolve_share_recipient()
RETURNS TRIGGER AS $$
DECLARE
  is_existing_accepted_contact boolean;
BEGIN
  -- Resolve shared_with_id from email (user_profiles or auth.users only)
  SELECT id INTO NEW.shared_with_id
  FROM public.user_profiles
  WHERE email = NEW.shared_with_email
     OR id IN (
       SELECT id FROM auth.users 
       WHERE email = NEW.shared_with_email
     )
  LIMIT 1;
  
  -- Existing accepted contacts can share immediately; new contacts require accept/decline
  SELECT EXISTS (
    SELECT 1 FROM public.task_shares
    WHERE owner_id = NEW.owner_id
      AND shared_with_id = NEW.shared_with_id
      AND status = 'accepted'
  ) INTO is_existing_accepted_contact;
  
  IF NEW.shared_with_id IS NOT NULL AND is_existing_accepted_contact THEN
    NEW.status := 'accepted';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enforce status lifecycle: pending, accepted, declined
ALTER TABLE public.task_shares
  DROP CONSTRAINT IF EXISTS task_shares_status_check;
ALTER TABLE public.task_shares
  ADD CONSTRAINT task_shares_status_check
  CHECK (status IN ('pending', 'accepted', 'declined'));

-- Recipients can UPDATE their own pending invites (accept/decline)
CREATE POLICY "Recipients can accept or decline pending invites"
  ON public.task_shares FOR UPDATE
  USING (auth.uid() = shared_with_id AND status = 'pending')
  WITH CHECK (auth.uid() = shared_with_id);

-- ============================================================
-- Phase 3: Notifications table for inbox/bell
-- ============================================================

CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type text NOT NULL,
  payload jsonb,
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own notifications"
  ON public.notifications FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications (mark read)"
  ON public.notifications FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own notifications"
  ON public.notifications FOR DELETE
  USING (auth.uid() = user_id);

-- Index for unread counts and inbox queries
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON public.notifications (user_id, read_at)
  WHERE read_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON public.notifications (user_id, created_at DESC);

-- Create notification when pending invite is created
CREATE OR REPLACE FUNCTION notify_task_share_invite()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'pending' AND NEW.shared_with_id IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, type, payload)
    VALUES (
      NEW.shared_with_id,
      'task_share_invite',
      jsonb_build_object(
        'task_share_id', NEW.id,
        'task_id', NEW.task_id,
        'owner_id', NEW.owner_id,
        'shared_with_email', NEW.shared_with_email
      )
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER notify_task_share_invite_trigger
  AFTER INSERT ON public.task_shares
  FOR EACH ROW
  EXECUTE FUNCTION notify_task_share_invite();

-- ============================================================
-- Enable Realtime for tasks and task_shares (idempotent)
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'tasks') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.tasks;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'task_shares') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.task_shares;
  END IF;
EXCEPTION WHEN OTHERS THEN
  NULL; -- Ignore if publication or tables don't exist
END $$;
