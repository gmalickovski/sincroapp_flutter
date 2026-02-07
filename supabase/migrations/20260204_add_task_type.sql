-- Add task_type column to tasks table in sincroapp schema
ALTER TABLE sincroapp.tasks ADD COLUMN IF NOT EXISTS task_type text DEFAULT 'task';

-- Update existing records: Appointment if reminder is set OR due_date has time
UPDATE sincroapp.tasks 
SET task_type = 'appointment' 
WHERE 
   (reminder_hour IS NOT NULL AND reminder_minute IS NOT NULL)
   OR
   (due_date IS NOT NULL AND (EXTRACT(HOUR FROM due_date) != 0 OR EXTRACT(MINUTE FROM due_date) != 0));

-- Add duration in minutes for appointments
ALTER TABLE sincroapp.tasks ADD COLUMN IF NOT EXISTS duration_minutes integer;
