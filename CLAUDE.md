@AGENTS.md

# MG Sakura Learning Platform

## About the client

MG Sakura Technical Institute Inc. is a Japanese language training school in General Santos City, Philippines. It offers **free** Japanese language training at beginner level (JLPT-style **A1–A2**), through **face-to-face** and **online** classes, plus support for Japanese exams and opportunities in Japan. It also provides free daycare as a student support service.

Identity: _A technical institute helping students develop practical Japanese-language skills through accessible online and classroom-based training._

## What we're building

One web platform with two sides:

1. **Student learning portal** — students log in and see their lessons, PDFs, worksheets, videos, class schedules, announcements, and materials assigned to them.
2. **Admin management system** — admins manage student records, courses, classes, enrollments, learning modes (face-to-face / online / hybrid), and upload/assign materials, all in one place.

## Scope rules (important)

- Build ONLY confirmed features (the two sides above).
- NOT confirmed yet — do NOT build unless asked: exams/quizzes, attendance, certificates, recorded tutorials, payments, job-placement tracking. Design the data model so these can be added later without rewrites, but don't implement them.
- Training is free: no pricing, billing, or payment UI anywhere.
- Users are Filipino learners, often on phones with slow/mobile data. Mobile-first, lightweight pages, compress media, lazy-load videos.

## Tech stack

**The stack is final: Next.js + Supabase + Vercel.** Don't suggest or add other
backends, databases, auth providers or hosts.

- **Next.js 16 (App Router) + TypeScript** — see the Next.js notes at the top of this file (from `AGENTS.md`). Check `node_modules/next/dist/docs/` before writing Next code. Known changes: `middleware.ts` is now **`proxy.ts`** (ours is `src/proxy.ts`); `cookies()` / `headers()` are async.
- **Styling — two systems, on purpose:**
  - **Homepage** (`src/app/(public)/`, `src/components/home/`) uses **CSS Modules** + design tokens. Keep it that way; don't convert it to Tailwind.
  - **Portal and admin** (`(auth)`, `(student)`, `admin`) use **Tailwind CSS v4 + shadcn/ui** (`src/components/ui/`, add components with `npx shadcn@latest add <name>`).
  - **`src/styles/tokens.css` is the single source of truth** for colors, fonts and radii. The shadcn variables in `src/app/globals.css` point at the tokens — change colors in `tokens.css`, not in `globals.css`.
- **Supabase**: Postgres database, Auth, Storage (PDFs/worksheets only — videos are YouTube links), Row Level Security
  - `src/lib/supabase/client.ts` — for Client Components
  - `src/lib/supabase/server.ts` — for Server Components / Server Actions / Route Handlers
  - `src/lib/supabase/proxy.ts` — session refresh, called from `src/proxy.ts`
  - `src/lib/supabase/database.types.ts` — generated table types (don't edit by hand)
- Deploy: **Vercel**
- Repo: github.com/Aaeyron/mg-sakura-learning-platform

## Folder structure

```
src/
  app/
    (public)/        homepage — CSS Modules
    (auth)/login/    login (Phase 3)
    (student)/       student portal, e.g. /dashboard (Phase 6)
    admin/           admin area, /admin (Phases 4–5)
    globals.css      Tailwind + shadcn theme, mapped to tokens
  components/
    home/            homepage sections (CSS Modules)
    ui/              shadcn/ui components
  lib/supabase/      Supabase clients
  styles/            tokens.css, reset.css, typography.css
  proxy.ts           runs before each request (session refresh)
supabase/
  migrations/       SQL migration files (structure only)
  scripts/          test_rls.sql security check
  config.toml       Supabase CLI config
```

## Database rules

- **Every structure change goes in a migration file** in `supabase/migrations/`: tables, columns, types, indexes, functions, triggers, RLS policies, storage buckets and storage policies. Never change structure in the Supabase dashboard.
- The dashboard is only for **changing data by hand** (e.g. making someone an admin).
- Never edit a migration that has already been pushed — write a new one.
- Workflow (Supabase CLI, installed as a dev dependency):
  - `npx supabase migration new <name>` — create a new migration file
  - `npx supabase db push` — apply new migrations to the linked project
  - `npx supabase gen types typescript --linked > src/lib/supabase/database.types.ts` — regenerate types after every schema change
  - `npx supabase db query --linked -f supabase/scripts/test_rls.sql` — security check (rolls back; report comes back as the error message). Update it when rules change.
- Helper functions for security rules live in the `private` schema (not exposed by the API) and are `security definer` with `set search_path = ''`.

## Secrets and keys

- `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` are safe in the browser (RLS protects the data).
- `SUPABASE_SECRET_KEY` bypasses all security rules. Use it **only in server code** (Server Actions / Route Handlers) — never with a `NEXT_PUBLIC_` name, never imported by a client component. Files that use it start with `import "server-only";`.

## Accounts and access decisions

- **Admins create student accounts** (public sign-ups are turned off in the Supabase dashboard). The admin sets a temporary password; `profiles.must_change_password` is `true`, and the student must change it on first login. After a successful change the app calls `supabase.rpc("complete_password_change")`.
- New accounts are always `student`. The role is never taken from sign-up data; admins are promoted by hand in the dashboard or by another admin.
- Enrollment status: `active` → full read access to the class; `completed` → keeps read-only access to that class's materials; `dropped` → loses access. `inactive` accounts see only their own profile.
- Students can edit only their own `full_name` and `phone` (enforced by a trigger).
- **Videos are unlisted YouTube links** (`materials.external_url`), not uploads. PDFs and worksheets go in the **private** `materials` Storage bucket (20 MB limit) and are opened with short-lived signed URLs.

## Roles

- `student` — sees only their own enrollments, classes, and assigned materials.
- `admin` — full access to manage everything.
- (Maybe later: `teacher`. Keep the role field flexible.)
- Enforce access with Supabase Row Level Security, not only in the UI.

## Core data model (starting point)

- `profiles` — id (= auth user id), full_name, role, contact info, status
- `courses` — e.g. "Japanese A1", "Japanese A2"; title, level, description
- `classes` — a batch/section of a course; course_id, name, learning_mode (face_to_face | online | hybrid), schedule, start/end dates, meeting link (for online)
- `enrollments` — student_id, class_id, status (active | completed | dropped), enrolled_at
- `materials` — title, type (lesson | pdf | worksheet | video | link), file path or URL, course_id, created_by
- `material_assignments` — material_id, class_id (materials are assigned per class)
- `announcements` — title, body, audience (all | specific class), published_at

## Design direction

Clean, friendly, Japanese-inspired, lots of white space, simple readable fonts.

- **Primary: crimson `#b4233c`** (`--color-primary`) — buttons, links, key actions.
- **Light sakura pink** (`--color-sakura-50/100/200`) — backgrounds and highlights only, never for text. In shadcn this is `secondary`, `accent`, `sidebar`, and the focus `ring`.
- Primary UI language: English (Japanese text appears in lesson content; use `--font-japanese` / the `font-jp` class).

## How to work with me

- I'm building this step by step. Before big changes, show a short plan and wait for my OK.
- Work one phase at a time. Don't jump ahead.
- Explain what you changed and why in simple terms — I'm still learning.
- Keep secrets in `.env.local` (git-ignored); never commit keys. `.env.example` lists the variables with placeholder values.
- Write SQL migrations as files in `supabase/migrations/`.

## Build phases

1. Project setup: Next.js + TS + Tailwind + Supabase client, folder structure, env setup ✅
2. Database schema + RLS policies (migrations)
3. Auth: login, role-based redirect (student → /dashboard, admin → /admin)
4. Admin: manage students, courses, classes, enrollments
5. Admin: upload materials to Supabase Storage + assign to classes; post announcements
6. Student portal: dashboard, my classes & schedule, my materials (view PDF, watch video), announcements
7. Polish: mobile layout, loading/empty states, basic tests, deploy to Vercel
