-- Change voice_corrections.task_id from CASCADE to SET NULL
-- so correction audit records survive task deletion
ALTER TABLE voice_corrections ALTER COLUMN task_id DROP NOT NULL;
ALTER TABLE voice_corrections DROP CONSTRAINT voice_corrections_task_id_fkey;
ALTER TABLE voice_corrections ADD CONSTRAINT voice_corrections_task_id_fkey 
  FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE SET NULL;
