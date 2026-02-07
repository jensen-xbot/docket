-- ============================================================
-- Add has_time flag for due dates
-- ============================================================

ALTER TABLE public.tasks
  ADD COLUMN has_time boolean NOT NULL DEFAULT false;
