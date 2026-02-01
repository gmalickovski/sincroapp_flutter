-- Migration to add gender to users table
ALTER TABLE sincroapp.users 
ADD COLUMN IF NOT EXISTS gender TEXT;
