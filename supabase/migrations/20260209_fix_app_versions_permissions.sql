-- FIX: Grant read access to app_versions table for all authenticated users
-- Error reported: permission denied for table app_versions (code 42501)

-- 1. Enable RLS (if not already enabled, good practice)
ALTER TABLE public.app_versions ENABLE ROW LEVEL SECURITY;

-- 2. Drop existing policy if exists to avoid conflicts
DROP POLICY IF EXISTS "Enable read access for all users" ON public.app_versions;
DROP POLICY IF EXISTS "Public app_versions access" ON public.app_versions;

-- 3. Create Policy: Allow SELECT for authenticated users (and anon if needed for login screen checks)
CREATE POLICY "Allow read access for all users"
ON public.app_versions
FOR SELECT
TO authenticated, anon
USING (true);

-- 4. Grant explicit table permissions (just in case)
GRANT SELECT ON public.app_versions TO anon;
GRANT SELECT ON public.app_versions TO authenticated;
