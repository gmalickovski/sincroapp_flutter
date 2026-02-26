-- Migration to add multiple reminders support (reminder_offsets)
ALTER TABLE sincroapp.tasks ADD COLUMN reminder_offsets int[] DEFAULT NULL;
