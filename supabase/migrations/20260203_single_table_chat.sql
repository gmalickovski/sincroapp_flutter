-- 1. Drop the separate conversations table and its foreign key
ALTER TABLE sincroapp.assistant_messages DROP CONSTRAINT IF EXISTS assistant_messages_conversation_id_fkey;
DROP TABLE IF EXISTS sincroapp.assistant_conversations;

-- 2. Ensure conversation_id exists (just a UUID now, no foreign key)
ALTER TABLE sincroapp.assistant_messages ADD COLUMN IF NOT EXISTS conversation_id uuid;

-- 3. Create a View to "simulate" the conversations table
-- This fetches the FIRST message of each conversation to serve as the Title and creation date.
CREATE OR REPLACE VIEW sincroapp.view_conversations AS
SELECT DISTINCT ON (conversation_id)
    conversation_id as id,
    user_id,
    content as title,
    created_at
FROM sincroapp.assistant_messages
WHERE conversation_id IS NOT NULL
ORDER BY conversation_id, created_at ASC;

-- 4. Grant access to the view
GRANT SELECT ON sincroapp.view_conversations TO authenticated;
GRANT SELECT ON sincroapp.view_conversations TO service_role;
