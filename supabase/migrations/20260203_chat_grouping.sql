-- Create conversations table
CREATE TABLE IF NOT EXISTS sincroapp.assistant_conversations (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Add conversation_id to messages
ALTER TABLE sincroapp.assistant_messages 
ADD COLUMN IF NOT EXISTS conversation_id uuid REFERENCES sincroapp.assistant_conversations(id) ON DELETE CASCADE;

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_assistant_conversations_user_id ON sincroapp.assistant_conversations(user_id);
CREATE INDEX IF NOT EXISTS idx_assistant_messages_conversation_id ON sincroapp.assistant_messages(conversation_id);

-- Policy to allow users to see their own conversations (Enable RLS first if not enabled)
ALTER TABLE sincroapp.assistant_conversations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own conversations" 
ON sincroapp.assistant_conversations FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own conversations" 
ON sincroapp.assistant_conversations FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own conversations" 
ON sincroapp.assistant_conversations FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own conversations" 
ON sincroapp.assistant_conversations FOR DELETE 
USING (auth.uid() = user_id);

-- Grant access to authenticated users (Required for custom schemas)
GRANT ALL ON TABLE sincroapp.assistant_conversations TO authenticated;
GRANT ALL ON TABLE sincroapp.assistant_conversations TO service_role;
