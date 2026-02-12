-- Correction log for voice personalization (audit + learning)
CREATE TABLE voice_corrections (
  id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  task_id uuid NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  field_name text NOT NULL,
  original_value text,
  corrected_value text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE voice_corrections ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_own_corrections" ON voice_corrections
  FOR ALL USING (auth.uid() = user_id);

CREATE INDEX idx_voice_corrections_user ON voice_corrections(user_id, created_at DESC);
