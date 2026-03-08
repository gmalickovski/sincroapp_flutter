-- Add recurrence_category to sincroapp.tasks table
-- Distinguishes between 'commitment' (Agendamento, fixed due date) and 'flow' (Ritual, dynamic)
-- It defaults to 'commitment' for all existing data to not break previous rules, 
-- but users can choose 'flow' for new tasks.

ALTER TABLE sincroapp.tasks 
ADD COLUMN IF NOT EXISTS recurrence_category TEXT DEFAULT 'commitment';

-- Add a check constraint to ensure values are only 'commitment' or 'flow' or null
ALTER TABLE sincroapp.tasks
ADD CONSTRAINT check_recurrence_category 
CHECK (recurrence_category IN ('commitment', 'flow'));
