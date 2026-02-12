-- Add recurrence support for tasks
ALTER TABLE tasks ADD COLUMN recurrence_rule TEXT;
