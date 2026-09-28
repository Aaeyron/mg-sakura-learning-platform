-- Phase 2 · 2/4: the core tables.
-- Security rules (RLS) for these tables are in the next migration.

-- ── profiles: one row per login account ────────────────────────────────────
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '',
  email text,
  phone text,
  role public.user_role not null default 'student',
  status public.profile_status not null default 'active',
  -- Admin-created accounts start with a temporary password. The app forces
  -- a password change on first login, then calls complete_password_change().
  must_change_password boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ── courses: what is taught (e.g. "Japanese A1") ───────────────────────────
create table public.courses (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  level public.course_level not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ── classes: a batch/section of a course ───────────────────────────────────
create table public.classes (
  id uuid primary key default gen_random_uuid(),
  -- restrict: a course with classes can't be deleted (archive it instead)
  course_id uuid not null references public.courses (id) on delete restrict,
  name text not null,
  learning_mode public.learning_mode not null,
  schedule text, -- plain text for now, e.g. "Mon & Wed, 6–8 PM"
  start_date date,
  end_date date,
  location text, -- face-to-face / hybrid
  meeting_url text, -- online / hybrid
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint classes_dates_in_order check (
    start_date is null or end_date is null or end_date >= start_date
  )
);

-- ── enrollments: which student is in which class ───────────────────────────
create table public.enrollments (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles (id) on delete cascade,
  -- restrict: a class with enrollments can't be deleted (keeps student history)
  class_id uuid not null references public.classes (id) on delete restrict,
  status public.enrollment_status not null default 'active',
  enrolled_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint enrollments_one_per_class unique (student_id, class_id)
);

-- ── materials: lessons, PDFs, worksheets, videos, links ────────────────────
create table public.materials (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  type public.material_type not null,
  content text, -- optional written lesson notes
  storage_path text unique, -- file in the private "materials" bucket
  external_url text, -- e.g. an unlisted YouTube link
  course_id uuid references public.courses (id) on delete set null,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint materials_one_source check (
    num_nonnulls(storage_path, external_url) <= 1
  ),
  constraint materials_not_empty check (
    num_nonnulls(storage_path, external_url, content) >= 1
  ),
  constraint materials_video_is_url check (
    type <> 'video' or external_url is not null
  ),
  constraint materials_pdf_is_file check (
    type <> 'pdf' or storage_path is not null
  )
);

-- ── material_assignments: which classes can see which material ─────────────
create table public.material_assignments (
  id uuid primary key default gen_random_uuid(),
  material_id uuid not null references public.materials (id) on delete cascade,
  class_id uuid not null references public.classes (id) on delete cascade,
  assigned_at timestamptz not null default now(),
  constraint material_assignments_once_per_class unique (material_id, class_id)
);

-- ── announcements ──────────────────────────────────────────────────────────
create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  class_id uuid references public.classes (id) on delete cascade, -- null = everyone
  published_at timestamptz, -- null = draft; in the future = scheduled
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ── indexes on foreign keys (fast lookups for joins and security rules) ────
create index classes_course_id_idx on public.classes (course_id);
create index enrollments_class_id_idx on public.enrollments (class_id);
create index materials_course_id_idx on public.materials (course_id);
create index materials_created_by_idx on public.materials (created_by);
create index material_assignments_class_id_idx on public.material_assignments (class_id);
create index announcements_class_id_idx on public.announcements (class_id);
create index announcements_published_at_idx on public.announcements (published_at);
create index announcements_created_by_idx on public.announcements (created_by);

-- ── keep updated_at current ────────────────────────────────────────────────
create trigger set_updated_at before update on public.profiles
  for each row execute function private.set_updated_at();
create trigger set_updated_at before update on public.courses
  for each row execute function private.set_updated_at();
create trigger set_updated_at before update on public.classes
  for each row execute function private.set_updated_at();
create trigger set_updated_at before update on public.enrollments
  for each row execute function private.set_updated_at();
create trigger set_updated_at before update on public.materials
  for each row execute function private.set_updated_at();
create trigger set_updated_at before update on public.announcements
  for each row execute function private.set_updated_at();

-- ── create a profile automatically for every new login account ─────────────
-- Everyone starts as a student. The role is never read from sign-up data,
-- because users can put anything in that.
create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', '')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- Keep profiles.email in sync if the login email changes.
create function private.sync_profile_email()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles set email = new.email where id = new.id;
  return new;
end;
$$;

create trigger on_auth_user_email_changed
  after update of email on auth.users
  for each row
  when (old.email is distinct from new.email)
  execute function private.sync_profile_email();

-- ── API access ─────────────────────────────────────────────────────────────
-- Logged-out visitors (anon) get nothing. Logged-in users get table access,
-- and the RLS policies in the next migration decide which ROWS they see.
revoke all on
  public.profiles, public.courses, public.classes, public.enrollments,
  public.materials, public.material_assignments, public.announcements
from anon;

grant select, insert, update, delete on
  public.profiles, public.courses, public.classes, public.enrollments,
  public.materials, public.material_assignments, public.announcements
to authenticated;
