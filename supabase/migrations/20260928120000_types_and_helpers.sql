-- Phase 2 · 1/4: fixed value lists and shared helpers.

-- Fixed value lists. To add a value later (e.g. a 'teacher' role), write a new
-- migration with: alter type public.user_role add value 'teacher';
create type public.user_role as enum ('student', 'admin');
create type public.profile_status as enum ('active', 'inactive');
create type public.course_level as enum ('A1', 'A2');
create type public.learning_mode as enum ('face_to_face', 'online', 'hybrid');
create type public.enrollment_status as enum ('active', 'completed', 'dropped');
create type public.material_type as enum ('lesson', 'pdf', 'worksheet', 'video', 'link');

-- Helper functions live in "private", which the Supabase API does not expose.
-- Logged-in users need USAGE so security rules can call these functions.
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

-- Keeps updated_at current on every row change.
create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
