-- ============================================================
-- Task Progress Tracking (v1.3)
-- ============================================================

-- Add progress columns to tasks
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS progress_percentage double precision DEFAULT 0.0;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS is_progress_enabled boolean DEFAULT false;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS last_progress_update timestamptz;

-- ============================================================
-- Shared Task Realtime Propagation
-- When a shared task is updated, touch task_shares so recipient
-- gets Realtime notification and pulls the latest data.
-- ============================================================

-- Add updated_at to task_shares for Realtime propagation
ALTER TABLE public.task_shares ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- Trigger: when a shared task is updated, touch its task_shares rows
CREATE OR REPLACE FUNCTION public.propagate_task_update_to_shares()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.task_shares
  SET updated_at = now()
  WHERE task_id = NEW.id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_shared_task_update ON public.tasks;
CREATE TRIGGER on_shared_task_update
  AFTER UPDATE ON public.tasks
  FOR EACH ROW
  WHEN (OLD.* IS DISTINCT FROM NEW.*)
  EXECUTE FUNCTION public.propagate_task_update_to_shares();
