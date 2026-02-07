-- ============================================================
-- Migrate country_code to country_iso
-- Allows distinguishing countries with same dial code (e.g., US vs CA both +1)
-- ============================================================

-- Add country_iso column if it doesn't exist
ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS country_iso text DEFAULT 'US';

-- Migrate existing country_code values to country_iso
-- If country_code exists and is +1, default to US (most common)
-- Otherwise, try to map dial codes to ISO codes
DO $$
BEGIN
    -- Only migrate if country_code column exists
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'user_profiles' 
        AND column_name = 'country_code'
    ) THEN
        -- Update country_iso based on country_code values
        -- Only migrate rows where country_iso is NULL (hasn't been set yet)
        UPDATE public.user_profiles
        SET country_iso = CASE
            WHEN country_code = '+1' THEN 'US'  -- Default +1 to US (most common)
            WHEN country_code = '+44' THEN 'GB'
            WHEN country_code = '+49' THEN 'DE'
            WHEN country_code = '+33' THEN 'FR'
            WHEN country_code = '+34' THEN 'ES'
            WHEN country_code = '+39' THEN 'IT'
            WHEN country_code = '+31' THEN 'NL'
            WHEN country_code = '+351' THEN 'PT'
            WHEN country_code = '+46' THEN 'SE'
            WHEN country_code = '+47' THEN 'NO'
            WHEN country_code = '+45' THEN 'DK'
            WHEN country_code = '+358' THEN 'FI'
            WHEN country_code = '+353' THEN 'IE'
            WHEN country_code = '+41' THEN 'CH'
            WHEN country_code = '+43' THEN 'AT'
            WHEN country_code = '+32' THEN 'BE'
            WHEN country_code = '+48' THEN 'PL'
            WHEN country_code = '+30' THEN 'GR'
            WHEN country_code = '+40' THEN 'RO'
            WHEN country_code = '+420' THEN 'CZ'
            WHEN country_code = '+36' THEN 'HU'
            WHEN country_code = '+380' THEN 'UA'
            WHEN country_code = '+7' THEN 'RU'
            WHEN country_code = '+55' THEN 'BR'
            WHEN country_code = '+54' THEN 'AR'
            WHEN country_code = '+57' THEN 'CO'
            WHEN country_code = '+56' THEN 'CL'
            WHEN country_code = '+51' THEN 'PE'
            WHEN country_code = '+81' THEN 'JP'
            WHEN country_code = '+82' THEN 'KR'
            WHEN country_code = '+86' THEN 'CN'
            WHEN country_code = '+91' THEN 'IN'
            WHEN country_code = '+63' THEN 'PH'
            WHEN country_code = '+66' THEN 'TH'
            WHEN country_code = '+84' THEN 'VN'
            WHEN country_code = '+60' THEN 'MY'
            WHEN country_code = '+65' THEN 'SG'
            WHEN country_code = '+62' THEN 'ID'
            WHEN country_code = '+92' THEN 'PK'
            WHEN country_code = '+880' THEN 'BD'
            WHEN country_code = '+971' THEN 'AE'
            WHEN country_code = '+966' THEN 'SA'
            WHEN country_code = '+972' THEN 'IL'
            WHEN country_code = '+90' THEN 'TR'
            WHEN country_code = '+27' THEN 'ZA'
            WHEN country_code = '+234' THEN 'NG'
            WHEN country_code = '+20' THEN 'EG'
            WHEN country_code = '+254' THEN 'KE'
            WHEN country_code = '+233' THEN 'GH'
            WHEN country_code = '+61' THEN 'AU'
            WHEN country_code = '+64' THEN 'NZ'
            WHEN country_code = '+52' THEN 'MX'
            ELSE 'US'  -- Default fallback
        END
        WHERE country_iso IS NULL;  -- Only migrate rows that haven't been set yet
        
        -- Drop the old country_code column after migration
        ALTER TABLE public.user_profiles DROP COLUMN IF EXISTS country_code;
    END IF;
END $$;

-- Ensure country_iso has a default for any new rows
ALTER TABLE public.user_profiles ALTER COLUMN country_iso SET DEFAULT 'US';
