-- ============================================
-- SINCRO APP - AUTOMATED CHAT HISTORY PRUNING
-- Strategy: Sliding Window (Keep Last N Messages)
-- ============================================

-- 1. Create Function to Prune Old Messages
-- This function will be triggered AFTER every INSERT on assistant_messages table.
-- It works per user, keeping only the N most recent messages.

CREATE OR REPLACE FUNCTION sincroapp.prune_chat_history()
RETURNS TRIGGER AS $$
DECLARE
    max_messages INTEGER := 50; -- Strategy: Keep last 50 messages (Context + Scroll History)
    messages_count INTEGER;
BEGIN
    -- Check how many messages this user has
    SELECT COUNT(*) INTO messages_count 
    FROM sincroapp.assistant_messages 
    WHERE user_id = NEW.user_id;

    -- If count exceeds limit, delete oldest
    IF messages_count > max_messages THEN
        DELETE FROM sincroapp.assistant_messages
        WHERE id IN (
            SELECT id FROM sincroapp.assistant_messages
            WHERE user_id = NEW.user_id
            ORDER BY created_at ASC -- Oldest first
            LIMIT (messages_count - max_messages) -- Delete excess
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Create Trigger
-- Fires after every new message is inserted.
-- Ensures the cleanup happens automatically in the DB layer.

DROP TRIGGER IF EXISTS trigger_prune_chat_history ON sincroapp.assistant_messages;

CREATE TRIGGER trigger_prune_chat_history
AFTER INSERT ON sincroapp.assistant_messages
FOR EACH ROW
EXECUTE FUNCTION sincroapp.prune_chat_history();

-- Comment explaining the strategy
COMMENT ON FUNCTION sincroapp.prune_chat_history IS 'Automated strategy to keep only the last 50 messages per user, preventing database bloat.';
