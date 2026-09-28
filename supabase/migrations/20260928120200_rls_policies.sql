-- Phase 2 · 3/4: Row Level Security.
-- Summary:
--   • Logged-out visitors: nothing.
--   • Students: their own profile, plus classes / courses / materials /
--     announcements for classes where their enrollment is 'active' or
--     'completed'. 'dropped' = no access. Read-only everywhere except their
--     own name and phone.
--   • Admins: everything.
--   • Inactive accounts: only their own profile.

-- ── helper functions ───────────────────────────────────────────────────────
-- SECURITY DEFINER lets these read profiles/enrollments without triggering
-- the RLS rules on those same tables (which would loop forever).

create function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid())
      and role = 'admin'
      and status = 'active'
  );
$$;

create function private.is_active_user()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and status = 'active'
  );
$$;

-- Classes the current user may see as a student.
create function private.my_class_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select e.class_id
  from public.enrollments e
  join public.profiles p on p.id = e.student_id
  where e.student_id = (select auth.uid())
    and e.status in ('active', 'completed')
    and p.status = 'active';
$$;

create function private.my_course_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select c.course_id
  from public.classes c
  where c.id in (select private.my_class_ids());
$$;

create function private.my_material_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select ma.material_id
  from public.material_assignments ma
  where ma.class_id in (select private.my_class_ids());
$$;

revoke all on function
  private.is_admin(), private.is_active_user(), private.my_class_ids(),
  private.my_course_ids(), private.my_material_ids()
from public;
grant execute on function
  private.is_admin(), private.is_active_user(), private.my_class_ids(),
  private.my_course_ids(), private.my_material_ids()
to authenticated;

-- ── turn on RLS everywhere ─────────────────────────────────────────────────
-- With RLS on and no matching policy, the answer is always "no".
alter table public.profiles enable row level security;
alter table public.courses enable row level security;
alter table public.classes enable row level security;
alter table public.enrollments enable row level security;
alter table public.materials enable row level security;
alter table public.material_assignments enable row level security;
alter table public.announcements enable row level security;

-- ── profiles ───────────────────────────────────────────────────────────────
-- No INSERT or DELETE policies: profiles are created by the sign-up trigger
-- and removed when the login account is deleted.
create policy "Read own profile, or any profile as admin"
  on public.profiles for select to authenticated
  using (id = (select auth.uid()) or (select private.is_admin()));

create policy "Update own profile, or any profile as admin"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()) or (select private.is_admin()))
  with check (id = (select auth.uid()) or (select private.is_admin()));

-- RLS decides which ROWS you can update, not which COLUMNS. This trigger
-- stops non-admins from changing anything except full_name and phone.
-- It only checks requests from the app ("authenticated"); the dashboard,
-- the server-only secret key, and our own SECURITY DEFINER functions are
-- trusted.
create function private.protect_profile_fields()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user = 'authenticated' and not private.is_admin() then
    if new.id is distinct from old.id
      or new.email is distinct from old.email
      or new.role is distinct from old.role
      or new.status is distinct from old.status
      or new.must_change_password is distinct from old.must_change_password
    then
      raise exception 'You can only change your own name and phone number.'
        using errcode = '42501'; -- insufficient_privilege
    end if;
  end if;
  return new;
end;
$$;

create trigger protect_profile_fields before update on public.profiles
  for each row execute function private.protect_profile_fields();

-- Called by the app after a student sets their own password on first login.
create function public.complete_password_change()
returns void
language sql
security definer
set search_path = ''
as $$
  update public.profiles
  set must_change_password = false
  where id = (select auth.uid());
$$;

revoke all on function public.complete_password_change() from public, anon;
grant execute on function public.complete_password_change() to authenticated;

-- ── courses ────────────────────────────────────────────────────────────────
create policy "Students read courses of their classes"
  on public.courses for select to authenticated
  using (id in (select private.my_course_ids()));

create policy "Admins manage courses"
  on public.courses for all to authenticated
  using ((select private.is_admin()))
  with check ((select private.is_admin()));

-- ── classes ────────────────────────────────────────────────────────────────
create policy "Students read their classes"
  on public.classes for select to authenticated
  using (id in (select private.my_class_ids()));

create policy "Admins manage classes"
  on public.classes for all to authenticated
  using ((select private.is_admin()))
  with check ((select private.is_admin()));

-- ── enrollments ────────────────────────────────────────────────────────────
create policy "Students read their own enrollments"
  on public.enrollments for select to authenticated
  using (student_id = (select auth.uid()) and (select private.is_active_user()));

create policy "Admins manage enrollments"
  on public.enrollments for all to authenticated
  using ((select private.is_admin()))
  with check ((select private.is_admin()));

-- ── materials ──────────────────────────────────────────────────────────────
create policy "Students read materials assigned to their classes"
  on public.materials for select to authenticated
  using (id in (select private.my_material_ids()));

create policy "Admins manage materials"
  on public.materials for all to authenticated
  using ((select private.is_admin()))
  with check ((select private.is_admin()));

-- ── material_assignments ───────────────────────────────────────────────────
create policy "Students read assignments for their classes"
  on public.material_assignments for select to authenticated
  using (class_id in (select private.my_class_ids()));

create policy "Admins manage material assignments"
  on public.material_assignments for all to authenticated
  using ((select private.is_admin()))
  with check ((select private.is_admin()));

-- ── announcements ──────────────────────────────────────────────────────────
-- Students only see published ones (not drafts, not scheduled for later),
-- addressed to everyone or to one of their classes.
create policy "Students read published announcements for them"
  on public.announcements for select to authenticated
  using (
    published_at is not null
    and published_at <= now()
    and (select private.is_active_user())
    and (class_id is null or class_id in (select private.my_class_ids()))
  );

create policy "Admins manage announcements"
  on public.announcements for all to authenticated
  using ((select private.is_admin()))
  with check ((select private.is_admin()));
