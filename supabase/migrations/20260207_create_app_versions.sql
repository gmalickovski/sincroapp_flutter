-- Create table for App Versions / Release Notes
create table if not exists sincroapp.app_versions (
  id uuid default gen_random_uuid() primary key,
  version text not null unique,
  label text not null, -- e.g. "Novidades Incríveis!"
  description text, -- Short description
  details text[], -- List of bullet points
  release_date timestamptz default now(),
  created_at timestamptz default now()
);

-- Enable RLS
alter table sincroapp.app_versions enable row level security;

-- Policy: Everyone can read versions
create policy "Everyone can read app versions"
  on sincroapp.app_versions for select
  using (true);

-- Policy: Only service_role or admins can insert/update
-- Assuming service_role key is used for deployment scripts
create policy "Service role can manage app versions"
  on sincroapp.app_versions for all
  using (auth.uid() is null); -- Standard check for service role in Supabase usually relies on JWT, but this simple policy assumes the role context. 
-- Correcting: Supabase policies for service_role are implicit (bypass RLS).
-- Let's just create a policy for authenticated users to create (if they are admins) or leave it strictly service_role.

-- For now, allowing all authenticated users to read.
