-- Voice personalization profiles (learned from corrections)
CREATE TABLE user_voice_profiles (
  id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  vocabulary_aliases jsonb NOT NULL DEFAULT '[]',
  category_mappings jsonb NOT NULL DEFAULT '[]',
  store_aliases jsonb NOT NULL DEFAULT '[]',
  time_habits jsonb NOT NULL DEFAULT '[]',
  personalization_enabled boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id)
);

ALTER TABLE user_voice_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_own_voice_profiles" ON user_voice_profiles
  FOR ALL USING (auth.uid() = user_id);
