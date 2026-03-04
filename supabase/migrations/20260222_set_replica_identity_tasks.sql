-- Enable FULL replica identity for tasks table so realtime DELETE and UPDATE events
-- include the previous column values, particularly user_id.
-- This ensures that Supabase's realtime streams with .eq('user_id', uid) filters
-- still receive the DELETE events properly and update the UI in real-time.

ALTER TABLE sincroapp.tasks REPLICA IDENTITY FULL;
