-- Migration to add 'title' to journal_entries and 'source_journal_id' to tasks (Schema: sincroapp)

DO $$ 
BEGIN 
    -- 1. Add 'title' to 'journal_entries' if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'sincroapp' 
                   AND table_name = 'journal_entries' 
                   AND column_name = 'title') THEN 
        ALTER TABLE sincroapp.journal_entries 
        ADD COLUMN title text;
    END IF; 

    -- 2. Add 'source_journal_id' to 'tasks' if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'sincroapp' 
                   AND table_name = 'tasks' 
                   AND column_name = 'source_journal_id') THEN 
        ALTER TABLE sincroapp.tasks 
        ADD COLUMN source_journal_id uuid REFERENCES sincroapp.journal_entries(id) ON DELETE SET NULL;
    END IF; 
END $$;
