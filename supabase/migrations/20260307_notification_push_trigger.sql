-- =============================================================================
-- Migration: Push Notification Trigger for Internal Notifications
-- Date: 2026-03-07
-- Description: Creates a trigger that sends FCM push notifications via Edge Function
--              whenever a new notification is inserted into sincroapp.notifications.
--              This covers: task_invite, contact_request, contact_accepted, 
--              task_update, sincro_alert, share, system.
--              Skips 'reminder' type (handled by send-task-reminders).
-- =============================================================================

-- Ensure pg_net is available
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 1. Create the trigger function
CREATE OR REPLACE FUNCTION sincroapp.notify_push_on_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Skip 'reminder' type (already handled by send-task-reminders Edge Function)
    IF NEW.type = 'reminder' THEN
        RETURN NEW;
    END IF;

    -- Call the Edge Function via pg_net (async HTTP POST)
    -- Uses the same URL pattern and service_role_key as pg_cron jobs
    PERFORM net.http_post(
        url := 'https://supabase.studiomlk.com.br/functions/v1/send-push-for-notification',
        headers := jsonb_build_object(
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjcxNjMxNjIsImV4cCI6MjA4MjUyMzE2MiwicmVmIjoic2luY3JvYXBwX3NlcnZpY2Vfcm9sZSJ9.memNmmKn9L2Xa9xyfw3DLuEXd1OPAl4TyRPdcGL7ToE',
            'Content-Type', 'application/json'
        ),
        body := jsonb_build_object(
            'notification_id', NEW.id
        )
    );

    RETURN NEW;
END;
$$;

-- 2. Create the trigger (drop if exists to avoid duplicates)
DROP TRIGGER IF EXISTS trigger_push_on_notification_insert ON sincroapp.notifications;

CREATE TRIGGER trigger_push_on_notification_insert
    AFTER INSERT ON sincroapp.notifications
    FOR EACH ROW
    EXECUTE FUNCTION sincroapp.notify_push_on_insert();

-- 3. Verify
DO $$
BEGIN
    RAISE NOTICE '✅ Trigger trigger_push_on_notification_insert created successfully!';
    RAISE NOTICE '   Every new notification (except reminders) will trigger a push via FCM.';
END $$;
