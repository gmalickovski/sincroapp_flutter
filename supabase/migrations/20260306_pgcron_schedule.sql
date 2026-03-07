-- ============================================================
-- pg_cron Schedule for Edge Functions (Self-Hosted Supabase)
-- Run this AFTER deploying Edge Functions
-- Requires pg_cron and pg_net extensions enabled
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Grant usage
GRANT USAGE ON SCHEMA cron TO postgres;

-- 1. Task Reminders - Every 1 minute
-- Checks task_reminders table for fire_at <= now() and sends FCM push
SELECT cron.schedule(
    'send-task-reminders',
    '* * * * *',
    $$
    SELECT net.http_post(
        url := 'https://supabase.studiomlk.com.br/functions/v1/send-task-reminders',
        headers := jsonb_build_object(
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjcxNjMxNjIsImV4cCI6MjA4MjUyMzE2MiwicmVmIjoic2luY3JvYXBwX3NlcnZpY2Vfcm9sZSJ9.memNmmKn9L2Xa9xyfw3DLuEXd1OPAl4TyRPdcGL7ToE',
            'Content-Type', 'application/json'
        ),
        body := '{}'::jsonb
    );
    $$
);

-- 2. Morning Notification - Daily at 08:30 BRT (11:30 UTC)
SELECT cron.schedule(
    'morning-notification',
    '30 11 * * *',
    $$
    SELECT net.http_post(
        url := 'https://supabase.studiomlk.com.br/functions/v1/morning-notification',
        headers := jsonb_build_object(
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjcxNjMxNjIsImV4cCI6MjA4MjUyMzE2MiwicmVmIjoic2luY3JvYXBwX3NlcnZpY2Vfcm9sZSJ9.memNmmKn9L2Xa9xyfw3DLuEXd1OPAl4TyRPdcGL7ToE',
            'Content-Type', 'application/json'
        ),
        body := '{}'::jsonb
    );
    $$
);

-- 3. Evening Review - Daily at 20:00 BRT (23:00 UTC)
SELECT cron.schedule(
    'evening-review',
    '0 23 * * *',
    $$
    SELECT net.http_post(
        url := 'https://supabase.studiomlk.com.br/functions/v1/evening-review',
        headers := jsonb_build_object(
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjcxNjMxNjIsImV4cCI6MjA4MjUyMzE2MiwicmVmIjoic2luY3JvYXBwX3NlcnZpY2Vfcm9sZSJ9.memNmmKn9L2Xa9xyfw3DLuEXd1OPAl4TyRPdcGL7ToE',
            'Content-Type', 'application/json'
        ),
        body := '{}'::jsonb
    );
    $$
);

-- 4. Cleanup old sent reminders (daily at 03:00 UTC)
SELECT cron.schedule(
    'cleanup-old-reminders',
    '0 3 * * *',
    $$
    DELETE FROM sincroapp.task_reminders
    WHERE sent = true
    AND sent_at < now() - interval '7 days';
    $$
);

-- View scheduled jobs
-- SELECT * FROM cron.job;
