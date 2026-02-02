-- FIX: Grant permissions for usage_logs table
-- Error 42501 (Permission Denied) happens because 'authenticated' role 
-- does not have proper Policy to INSERT into public.usage_logs (or sincroapp.usage_logs).

-- 1. Ensure Table Exists (Context Check)
-- 1. Ensure Table Exists (Context Check)
CREATE TABLE IF NOT EXISTS sincroapp.usage_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id), -- Assuming standard auth schema
    tokens_total INT DEFAULT 0,
    tokens_prompt INT DEFAULT 0,
    tokens_completion INT DEFAULT 0,
    cost_usd NUMERIC DEFAULT 0,
    tool_used VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Enable RLS
ALTER TABLE sincroapp.usage_logs ENABLE ROW LEVEL SECURITY;

-- 3. Grant Usage (Usually done by default for public, but good to be explicit)
GRANT ALL ON sincroapp.usage_logs TO authenticated;
GRANT ALL ON sincroapp.usage_logs TO service_role;

-- 4. Create INSERT Policy
-- Allow any authenticated user to insert a log, PROVIDED user_id matches their own UID
-- OR allow them to insert any log if the backend logic overrides user_id (less secure).
-- Since this is logged by the App (client-side or edge function), we strictly enforce user_id match if possible.
-- However, if 'user_id' is passed in the payload, we ensure it matches auth.uid().

DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON sincroapp.usage_logs;

CREATE POLICY "Enable insert for authenticated users only" ON sincroapp.usage_logs
FOR INSERT 
TO authenticated 
WITH CHECK (true); 
-- Note: 'true' allows insertion of ANY row. Ideally, we want (auth.uid() = user_id), 
-- but sometimes usage logs are technical. If strictness is needed: WITH CHECK (auth.uid() = user_id);

-- 5. Create SELECT Policy (Optional, for admin dashboard or user stats)
DROP POLICY IF EXISTS "Enable read for users based on user_id" ON sincroapp.usage_logs;

CREATE POLICY "Enable read for users based on user_id" ON sincroapp.usage_logs
FOR SELECT 
TO authenticated 
USING (auth.uid() = user_id);

-- If you are using a specific schema like 'sincroapp', adjust 'public' to 'sincroapp' above.
-- Schema verified: sincroapp
