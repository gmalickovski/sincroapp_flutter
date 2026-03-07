-- ============================================================
-- Migration: Professional Notification System
-- Creates task_reminders table, trigger, and cleanup columns
-- ============================================================

-- 0. Ensure reminder_offsets column exists as JSONB
-- (may not exist, or may exist as int[] from older migration)
DO $$
BEGIN
    -- Check if column exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'sincroapp' 
        AND table_name = 'tasks' 
        AND column_name = 'reminder_offsets'
    ) THEN
        -- Column doesn't exist, create as jsonb
        ALTER TABLE sincroapp.tasks ADD COLUMN reminder_offsets jsonb DEFAULT NULL;
    ELSE
        -- Column exists, check if it's int[] and convert to jsonb
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'sincroapp' 
            AND table_name = 'tasks' 
            AND column_name = 'reminder_offsets'
            AND data_type = 'ARRAY'
        ) THEN
            -- Convert int[] to jsonb: e.g. {10,30} -> [10,30]
            ALTER TABLE sincroapp.tasks 
                ALTER COLUMN reminder_offsets TYPE jsonb 
                USING to_jsonb(reminder_offsets);
        END IF;
    END IF;
END $$;

-- 1. Create task_reminders table
-- Each row represents a single scheduled reminder for a task
CREATE TABLE IF NOT EXISTS sincroapp.task_reminders (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    task_id uuid NOT NULL REFERENCES sincroapp.tasks(id) ON DELETE CASCADE,
    user_id uuid NOT NULL,
    offset_minutes integer NOT NULL DEFAULT 0,
    fire_at timestamptz NOT NULL,
    sent boolean DEFAULT false,
    sent_at timestamptz,
    created_at timestamptz DEFAULT now()
);

-- Indexes for fast querying
CREATE INDEX IF NOT EXISTS idx_task_reminders_pending 
    ON sincroapp.task_reminders (fire_at) 
    WHERE sent = false;

CREATE INDEX IF NOT EXISTS idx_task_reminders_task 
    ON sincroapp.task_reminders (task_id);

CREATE INDEX IF NOT EXISTS idx_task_reminders_user 
    ON sincroapp.task_reminders (user_id);

-- 2. Enable RLS
ALTER TABLE sincroapp.task_reminders ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can read their own reminders
CREATE POLICY "Users can view own reminders" 
    ON sincroapp.task_reminders FOR SELECT 
    USING (user_id = auth.uid());

-- Service role can do anything (for Edge Functions)
CREATE POLICY "Service role full access" 
    ON sincroapp.task_reminders FOR ALL 
    USING (auth.role() = 'service_role');

-- 3. Create trigger function
CREATE OR REPLACE FUNCTION sincroapp.sync_task_reminders()
RETURNS TRIGGER AS $$
BEGIN
    -- On DELETE: cascade handles cleanup automatically
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    -- Remove pending (unsent) reminders for this task
    DELETE FROM sincroapp.task_reminders 
    WHERE task_id = NEW.id AND sent = false;

    -- If task is completed, don't create new reminders
    IF NEW.completed = true THEN
        RETURN NEW;
    END IF;

    -- Strategy 1: Use reminder_offsets (modern system)
    IF NEW.due_date IS NOT NULL 
       AND NEW.reminder_offsets IS NOT NULL 
       AND jsonb_typeof(NEW.reminder_offsets) = 'array'
       AND jsonb_array_length(NEW.reminder_offsets) > 0 THEN
        
        INSERT INTO sincroapp.task_reminders (task_id, user_id, offset_minutes, fire_at)
        SELECT 
            NEW.id,
            NEW.user_id,
            (offset_val)::integer,
            NEW.due_date - ((offset_val)::integer * interval '1 minute')
        FROM jsonb_array_elements_text(NEW.reminder_offsets) AS offset_val
        -- Only create reminders that haven't passed yet (with 5 min grace)
        WHERE NEW.due_date - ((offset_val)::integer * interval '1 minute') > (now() - interval '5 minutes');
    
    -- Strategy 2: Fallback to legacy reminder_at
    ELSIF NEW.reminder_at IS NOT NULL AND NEW.due_date IS NOT NULL THEN
        INSERT INTO sincroapp.task_reminders (task_id, user_id, offset_minutes, fire_at)
        VALUES (NEW.id, NEW.user_id, 0, NEW.reminder_at)
        -- Only if reminder hasn't passed
        ON CONFLICT DO NOTHING;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Create trigger on tasks table
DROP TRIGGER IF EXISTS trg_sync_task_reminders ON sincroapp.tasks;

CREATE TRIGGER trg_sync_task_reminders
AFTER INSERT OR UPDATE OF due_date, reminder_offsets, reminder_at, completed
ON sincroapp.tasks
FOR EACH ROW EXECUTE FUNCTION sincroapp.sync_task_reminders();

-- 5. Backfill: Create reminders for existing tasks that have reminder_offsets
INSERT INTO sincroapp.task_reminders (task_id, user_id, offset_minutes, fire_at)
SELECT 
    t.id,
    t.user_id,
    (offset_val)::integer,
    t.due_date - ((offset_val)::integer * interval '1 minute')
FROM sincroapp.tasks t,
     jsonb_array_elements_text(t.reminder_offsets) AS offset_val
WHERE t.completed = false
  AND t.due_date IS NOT NULL
  AND t.reminder_offsets IS NOT NULL
  AND jsonb_typeof(t.reminder_offsets) = 'array'
  AND jsonb_array_length(t.reminder_offsets) > 0
  AND t.due_date - ((offset_val)::integer * interval '1 minute') > now()
ON CONFLICT DO NOTHING;

-- 6. Drop unused columns
ALTER TABLE sincroapp.tasks DROP COLUMN IF EXISTS reminder_hour;
ALTER TABLE sincroapp.tasks DROP COLUMN IF EXISTS reminder_minute;
ALTER TABLE sincroapp.tasks DROP COLUMN IF EXISTS shared_from_user_id;
-- reminder_sent is now tracked per-reminder in task_reminders.sent
ALTER TABLE sincroapp.tasks DROP COLUMN IF EXISTS reminder_sent;

-- 7. Grant permissions for service role
GRANT ALL ON sincroapp.task_reminders TO service_role;
GRANT SELECT ON sincroapp.task_reminders TO authenticated;
