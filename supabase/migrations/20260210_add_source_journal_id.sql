-- Add source_journal_id column to tasks table if it doesn't exist (Schema: sincroapp)

DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'sincroapp' 
                   AND table_name = 'tasks' 
                   AND column_name = 'source_journal_id') THEN 
        ALTER TABLE sincroapp.tasks 
        ADD COLUMN source_journal_id uuid REFERENCES sincroapp.journal_entries(id) ON DELETE SET NULL;
    END IF; 
END $$;
