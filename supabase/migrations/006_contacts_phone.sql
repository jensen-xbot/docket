-- Add phone number support to contacts
ALTER TABLE public.contacts ADD COLUMN IF NOT EXISTS contact_phone text;

-- Update unique constraint to allow same user to have contact by email or phone
-- (keep existing constraint, phone is optional)
