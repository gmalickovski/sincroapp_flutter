-- SQL to add 'focused_at' column to the tasks table for the SincroApp.
-- Run this in your Supabase SQL Editor.

ALTER TABLE sincroapp.tasks
ADD COLUMN IF NOT EXISTS focused_at TIMESTAMP WITH TIME ZONE NULL;

COMMENT ON COLUMN sincroapp.tasks.focused_at IS 'Timestamp of when the task was marked as is_focus=true';
scm-history-item:c%3A%5Cdev%5Csincro_app_flutter?%7B%22repositoryId%22%3A%22scm0%22%2C%22historyItemId%22%3A%22f945191aeedbd770015e14a04dc7029ea1167bd1%22%2C%22historyItemParentId%22%3A%22c270e3222ca6a27f548698c46cd4ef2bdec2388a%22%2C%22historyItemDisplayId%22%3A%22f945191%22%7D