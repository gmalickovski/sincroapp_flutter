-- migration: reset_is_focus_daily

-- Configura a extensão pg_cron se ainda não estiver habilitada
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Agenda a tarefa para ser executada todos os dias às 00:00 (meia-noite)
SELECT cron.schedule(
    'reset_is_focus_daily',
    '0 0 * * *',
    $$
    UPDATE sincroapp.tasks
    SET is_focus = false
    WHERE is_focus = true;
    $$
);
