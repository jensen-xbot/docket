-- Add task source and voice snapshot for personalization tracking
ALTER TABLE tasks ADD COLUMN task_source TEXT DEFAULT NULL;
ALTER TABLE tasks ADD COLUMN voice_snapshot JSONB DEFAULT NULL;
