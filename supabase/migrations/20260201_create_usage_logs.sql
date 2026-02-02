-- Create usage_logs table to track AI token consumption and user activity
CREATE TABLE IF NOT EXISTS sincroapp.usage_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    request_type TEXT NOT NULL, -- 'chat_message', 'action_proposal', 'numerology', etc.
    tokens_input INTEGER DEFAULT 0,
    tokens_output INTEGER DEFAULT 0,
    tokens_total INTEGER DEFAULT 0,
    model_name TEXT, -- 'gpt-4o', 'gpt-3.5-turbo', etc. check if available
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE sincroapp.usage_logs ENABLE ROW LEVEL SECURITY;

-- Policies
-- Admin can view all
CREATE POLICY "Admins can view all usage logs" ON sincroapp.usage_logs
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM sincroapp.users 
            WHERE uid = auth.uid() 
            AND is_admin = true
        )
    );

-- Users can view their own (optional, but good for transparency if needed later)
CREATE POLICY "Users can view own usage logs" ON sincroapp.usage_logs
    FOR SELECT
    USING (auth.uid() = user_id);

-- System/Service role can insert (usually handled by service role key in edge functions, but if inserting from client using specific function, we might need a function. 
-- However, since the APP is inserting this data based on N8n response, it acts as the user.
-- ALLOW insert for authenticated users for their own records.
CREATE POLICY "Users can insert own usage logs" ON sincroapp.usage_logs
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Create index for performance on stats queries
CREATE INDEX idx_usage_logs_user_id ON sincroapp.usage_logs(user_id);
CREATE INDEX idx_usage_logs_created_at ON sincroapp.usage_logs(created_at);
