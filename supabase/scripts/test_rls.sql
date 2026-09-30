-- Security (RLS) check for the linked Supabase project.
--
-- Run:  npx supabase db query --linked -f supabase/scripts/test_rls.sql
--
-- It creates pretend users and data, tries things as each type of user, and
-- then deliberately raises an error at the end. The error UNDOES everything
-- (nothing is saved) and carries the PASS/FAIL report as its message.

do $test$
declare
  r text := '';
  n int;
  flag boolean;
  txt text;

  -- people
  admin_id uuid := gen_random_uuid();
  v_student uuid := gen_random_uuid();   -- active in c_active, completed in c_done, dropped in c_dropped
  inactive_id uuid := gen_random_uuid();  -- account set to inactive, active in c_other
  sneaky_id uuid := gen_random_uuid();    -- signs up claiming to be an admin

  co_a1 uuid := gen_random_uuid();
  co_a2 uuid := gen_random_uuid();
  c_active uuid := gen_random_uuid();
  c_done uuid := gen_random_uuid();
  c_dropped uuid := gen_random_uuid();
  c_other uuid := gen_random_uuid();

  m_active uuid := gen_random_uuid();
  m_done uuid := gen_random_uuid();
  m_dropped uuid := gen_random_uuid();
  m_other uuid := gen_random_uuid();
  m_unassigned uuid := gen_random_uuid();

  all_courses uuid[];
  all_classes uuid[];
  all_materials uuid[];
  all_profiles uuid[];
begin
  all_courses := array[co_a1, co_a2];
  all_classes := array[c_active, c_done, c_dropped, c_other];
  all_materials := array[m_active, m_done, m_dropped, m_other, m_unassigned];
  all_profiles := array[admin_id, v_student, inactive_id, sneaky_id];

  -- ── setup (as the database owner) ──────────────────────────────────────
  insert into auth.users (id, email, aud, role, raw_user_meta_data) values
    (admin_id, 'rls-admin@test.local', 'authenticated', 'authenticated', '{"full_name":"Test Admin"}'),
    (v_student, 'rls-student@test.local', 'authenticated', 'authenticated', '{"full_name":"Test Student"}'),
    (inactive_id, 'rls-inactive@test.local', 'authenticated', 'authenticated', '{"full_name":"Test Inactive"}'),
    (sneaky_id, 'rls-sneaky@test.local', 'authenticated', 'authenticated', '{"full_name":"Sneaky","role":"admin"}');

  -- Sign-up trigger checks
  select count(*) into n from public.profiles where id = any(all_profiles);
  r := r || E'\n' || (case when n = 4 then 'PASS' else 'FAIL' end)
    || ' | [signup] A profile is created automatically for each new account (got ' || n || '/4)';

  select role::text, must_change_password into txt, flag from public.profiles where id = sneaky_id;
  r := r || E'\n' || (case when txt = 'student' then 'PASS' else 'FAIL' end)
    || ' | [signup] Claiming "role: admin" at sign-up still gives a student (got ' || txt || ')';
  r := r || E'\n' || (case when flag then 'PASS' else 'FAIL' end)
    || ' | [signup] New accounts must change their password (must_change_password = true)';

  update public.profiles set role = 'admin', must_change_password = false where id = admin_id;
  update public.profiles set status = 'inactive' where id = inactive_id;

  insert into public.courses (id, title, level) values
    (co_a1, 'RLS Test A1', 'A1'), (co_a2, 'RLS Test A2', 'A2');
  insert into public.classes (id, course_id, name, learning_mode, meeting_url) values
    (c_active, co_a1, 'RLS active class', 'online', 'https://meet.example/active'),
    (c_done, co_a1, 'RLS completed class', 'face_to_face', null),
    (c_dropped, co_a2, 'RLS dropped class', 'online', 'https://meet.example/dropped'),
    (c_other, co_a2, 'RLS other class', 'hybrid', 'https://meet.example/other');
  insert into public.enrollments (student_id, class_id, status) values
    (v_student, c_active, 'active'),
    (v_student, c_done, 'completed'),
    (v_student, c_dropped, 'dropped'),
    (inactive_id, c_other, 'active');
  insert into public.materials (id, title, type, storage_path, external_url, content) values
    (m_active, 'RLS active pdf', 'pdf', 'rls-test/active.pdf', null, null),
    (m_done, 'RLS completed video', 'video', null, 'https://youtu.be/test', null),
    (m_dropped, 'RLS dropped pdf', 'pdf', 'rls-test/dropped.pdf', null, null),
    (m_other, 'RLS other lesson', 'lesson', null, null, 'Notes'),
    (m_unassigned, 'RLS unassigned pdf', 'pdf', 'rls-test/unassigned.pdf', null, null);
  insert into public.material_assignments (material_id, class_id) values
    (m_active, c_active), (m_done, c_done), (m_dropped, c_dropped), (m_other, c_other);
  insert into public.announcements (title, body, class_id, published_at) values
    ('RLS everyone published', 'x', null, now() - interval '1 day'),
    ('RLS everyone draft', 'x', null, null),
    ('RLS everyone scheduled', 'x', null, now() + interval '7 days'),
    ('RLS active class published', 'x', c_active, now() - interval '1 hour'),
    ('RLS dropped class published', 'x', c_dropped, now() - interval '1 hour'),
    ('RLS other class published', 'x', c_other, now() - interval '1 hour');
  insert into storage.objects (bucket_id, name) values
    ('materials', 'rls-test/active.pdf'),
    ('materials', 'rls-test/dropped.pdf'),
    ('materials', 'rls-test/unassigned.pdf');

  -- ── LOGGED-OUT VISITOR ─────────────────────────────────────────────────
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  execute 'set local role anon';

  begin
    select count(*) into n from public.profiles;
    r := r || E'\n' || 'FAIL | [visitor] Cannot read profiles (read ' || n || ' rows)';
  exception when others then
    r := r || E'\n' || 'PASS | [visitor] Cannot read profiles' || ' → ' || sqlerrm;
  end;
  begin
    select count(*) into n from public.classes;
    r := r || E'\n' || 'FAIL | [visitor] Cannot read classes (read ' || n || ' rows)';
  exception when others then
    r := r || E'\n' || 'PASS | [visitor] Cannot read classes' || ' → ' || sqlerrm;
  end;
  begin
    select count(*) into n from public.materials;
    r := r || E'\n' || 'FAIL | [visitor] Cannot read materials (read ' || n || ' rows)';
  exception when others then
    r := r || E'\n' || 'PASS | [visitor] Cannot read materials' || ' → ' || sqlerrm;
  end;
  begin
    select count(*) into n from storage.objects where bucket_id = 'materials';
    r := r || E'\n' || (case when n = 0 then 'PASS' else 'FAIL' end)
      || ' | [visitor] Cannot see any stored files (saw ' || n || ')';
  exception when others then
    r := r || E'\n' || 'PASS | [visitor] Cannot see any stored files' || ' → ' || sqlerrm;
  end;

  execute 'reset role';

  -- ── STUDENT (active in 1 class, completed 1, dropped 1) ────────────────
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_student, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';

  select count(*) into n from public.profiles;
  r := r || E'\n' || (case when n = 1 then 'PASS' else 'FAIL' end)
    || ' | [student] Sees only their own profile (saw ' || n || ')';

  update public.profiles set full_name = 'New Name', phone = '09171234567' where id = v_student;
  get diagnostics n = row_count;
  r := r || E'\n' || (case when n = 1 then 'PASS' else 'FAIL' end)
    || ' | [student] Can change their own name and phone';

  begin
    update public.profiles set role = 'admin' where id = v_student;
    r := r || E'\n' || 'FAIL | [student] Cannot make themselves an admin';
  exception when others then
    r := r || E'\n' || 'PASS | [student] Cannot make themselves an admin' || ' → ' || sqlerrm;
  end;
  begin
    update public.profiles set status = 'inactive' where id = v_student;
    r := r || E'\n' || 'FAIL | [student] Cannot change their account status';
  exception when others then
    r := r || E'\n' || 'PASS | [student] Cannot change their account status' || ' → ' || sqlerrm;
  end;
  begin
    update public.profiles set must_change_password = false where id = v_student;
    r := r || E'\n' || 'FAIL | [student] Cannot switch off "must change password" by editing the row';
  exception when others then
    r := r || E'\n' || 'PASS | [student] Cannot switch off "must change password" by editing the row' || ' → ' || sqlerrm;
  end;

  update public.profiles set full_name = 'Hacked' where id = admin_id;
  get diagnostics n = row_count;
  r := r || E'\n' || (case when n = 0 then 'PASS' else 'FAIL' end)
    || ' | [student] Cannot edit someone else''s profile';

  perform public.complete_password_change();
  select must_change_password into flag from public.profiles where id = v_student;
  r := r || E'\n' || (case when flag = false then 'PASS' else 'FAIL' end)
    || ' | [student] complete_password_change() clears their own flag';

  select count(*) into n from public.classes;
  r := r || E'\n' || (case when n = 2 then 'PASS' else 'FAIL' end)
    || ' | [student] Sees their active + completed classes only (saw ' || n || '/2)';
  select count(*) into n from public.classes where id = c_dropped;
  r := r || E'\n' || (case when n = 0 then 'PASS' else 'FAIL' end)
    || ' | [student] Cannot see the class they dropped (or its meeting link)';
  select count(*) into n from public.courses;
  r := r || E'\n' || (case when n = 1 then 'PASS' else 'FAIL' end)
    || ' | [student] Sees only courses of their classes (saw ' || n || '/1)';
  select count(*) into n from public.enrollments;
  r := r || E'\n' || (case when n = 3 then 'PASS' else 'FAIL' end)
    || ' | [student] Sees their own 3 enrollment records, nobody else''s (saw ' || n || ')';
  select count(*) into n from public.materials;
  r := r || E'\n' || (case when n = 2 then 'PASS' else 'FAIL' end)
    || ' | [student] Sees materials of active + completed classes only (saw ' || n || '/2)';
  select count(*) into n from public.materials where id in (m_dropped, m_other, m_unassigned);
  r := r || E'\n' || (case when n = 0 then 'PASS' else 'FAIL' end)
    || ' | [student] Cannot see dropped-class, other-class or unassigned materials';
  select count(*) into n from public.material_assignments;
  r := r || E'\n' || (case when n = 2 then 'PASS' else 'FAIL' end)
    || ' | [student] Sees material assignments for their classes only (saw ' || n || '/2)';

  select string_agg(title, ', ' order by title) into txt from public.announcements;
  select count(*) into n from public.announcements;
  r := r || E'\n' || (case when n = 2 then 'PASS' else 'FAIL' end)
    || ' | [student] Sees only published announcements for everyone/their class (saw: ' || coalesce(txt, 'none') || ')';

  select count(*) into n from storage.objects where bucket_id = 'materials';
  select string_agg(name, ', ') into txt from storage.objects where bucket_id = 'materials';
  r := r || E'\n' || (case when n = 1 then 'PASS' else 'FAIL' end)
    || ' | [student] Can open only the file for their assigned material (saw: ' || coalesce(txt, 'none') || ')';

  begin
    insert into public.courses (title, level) values ('Sneaky course', 'A1');
    r := r || E'\n' || 'FAIL | [student] Cannot create courses';
  exception when others then
    r := r || E'\n' || 'PASS | [student] Cannot create courses' || ' → ' || sqlerrm;
  end;
  begin
    insert into public.enrollments (student_id, class_id) values (v_student, c_other);
    r := r || E'\n' || 'FAIL | [student] Cannot enroll themselves in a class';
  exception when others then
    r := r || E'\n' || 'PASS | [student] Cannot enroll themselves in a class' || ' → ' || sqlerrm;
  end;
  begin
    update public.enrollments set status = 'active' where class_id = c_dropped;
    get diagnostics n = row_count;
    r := r || E'\n' || (case when n = 0 then 'PASS' else 'FAIL' end)
      || ' | [student] Cannot un-drop themselves (change enrollment status)';
  exception when others then
    r := r || E'\n' || 'PASS | [student] Cannot un-drop themselves (change enrollment status)' || ' → ' || sqlerrm;
  end;
  update public.classes set name = 'Hacked' where id = c_active;
  get diagnostics n = row_count;
  r := r || E'\n' || (case when n = 0 then 'PASS' else 'FAIL' end)
    || ' | [student] Cannot edit their class';
  delete from public.materials where id = m_active;
  get diagnostics n = row_count;
  r := r || E'\n' || (case when n = 0 then 'PASS' else 'FAIL' end)
    || ' | [student] Cannot delete materials';
  begin
    insert into public.announcements (title, body) values ('Sneaky', 'x');
    r := r || E'\n' || 'FAIL | [student] Cannot post announcements';
  exception when others then
    r := r || E'\n' || 'PASS | [student] Cannot post announcements' || ' → ' || sqlerrm;
  end;
  begin
    insert into public.profiles (id, full_name) values (gen_random_uuid(), 'Fake');
    r := r || E'\n' || 'FAIL | [student] Cannot create profiles';
  exception when others then
    r := r || E'\n' || 'PASS | [student] Cannot create profiles' || ' → ' || sqlerrm;
  end;
  begin
    insert into storage.objects (bucket_id, name) values ('materials', 'rls-test/sneaky.pdf');
    r := r || E'\n' || 'FAIL | [student] Cannot upload files';
  exception when others then
    r := r || E'\n' || 'PASS | [student] Cannot upload files' || ' → ' || sqlerrm;
  end;

  execute 'reset role';

  -- ── INACTIVE STUDENT (account switched off, still enrolled) ────────────
  perform set_config('request.jwt.claims',
    json_build_object('sub', inactive_id, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';

  select count(*) into n from public.profiles;
  r := r || E'\n' || (case when n = 1 then 'PASS' else 'FAIL' end)
    || ' | [inactive] Can still see their own profile (so the app can explain why)';
  select (select count(*) from public.classes) + (select count(*) from public.materials)
       + (select count(*) from public.announcements) + (select count(*) from public.enrollments)
       + (select count(*) from storage.objects where bucket_id = 'materials')
    into n;
  r := r || E'\n' || (case when n = 0 then 'PASS' else 'FAIL' end)
    || ' | [inactive] Sees no classes, materials, announcements or files (saw ' || n || ' rows)';

  execute 'reset role';

  -- ── ADMIN ──────────────────────────────────────────────────────────────
  perform set_config('request.jwt.claims',
    json_build_object('sub', admin_id, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';

  select count(*) into n from public.profiles where id = any(all_profiles);
  r := r || E'\n' || (case when n = 4 then 'PASS' else 'FAIL' end)
    || ' | [admin] Sees every profile (saw ' || n || '/4)';
  select count(*) into n from public.classes where id = any(all_classes);
  r := r || E'\n' || (case when n = 4 then 'PASS' else 'FAIL' end)
    || ' | [admin] Sees every class (saw ' || n || '/4)';
  select count(*) into n from public.materials where id = any(all_materials);
  r := r || E'\n' || (case when n = 5 then 'PASS' else 'FAIL' end)
    || ' | [admin] Sees every material, including unassigned (saw ' || n || '/5)';
  select count(*) into n from public.announcements where title like 'RLS %';
  r := r || E'\n' || (case when n = 6 then 'PASS' else 'FAIL' end)
    || ' | [admin] Sees every announcement, including drafts and scheduled (saw ' || n || '/6)';
  select count(*) into n from storage.objects where bucket_id = 'materials' and name like 'rls-test/%';
  r := r || E'\n' || (case when n = 3 then 'PASS' else 'FAIL' end)
    || ' | [admin] Sees every stored file (saw ' || n || '/3)';

  begin
    insert into public.courses (title, level) values ('RLS admin course', 'A2');
    update public.classes set name = 'Renamed by admin' where id = c_active;
    insert into public.enrollments (student_id, class_id) values (v_student, c_other);
    update public.enrollments set status = 'dropped' where student_id = v_student and class_id = c_active;
    insert into public.material_assignments (material_id, class_id) values (m_unassigned, c_active);
    insert into public.announcements (title, body, published_at) values ('RLS by admin', 'x', now());
    delete from public.announcements where title = 'RLS everyone draft';
    r := r || E'\n' || 'PASS | [admin] Can create/edit/delete courses, classes, enrollments, assignments, announcements';
  exception when others then
    r := r || E'\n' || 'FAIL | [admin] Can create/edit/delete courses, classes, enrollments, assignments, announcements (' || sqlerrm || ')';
  end;
  begin
    update public.profiles set status = 'inactive', must_change_password = true, full_name = 'Edited'
      where id = sneaky_id;
    get diagnostics n = row_count;
    r := r || E'\n' || (case when n = 1 then 'PASS' else 'FAIL' end)
      || ' | [admin] Can edit a student''s name, status and password flag';
  exception when others then
    r := r || E'\n' || 'FAIL | [admin] Can edit a student''s name, status and password flag (' || sqlerrm || ')';
  end;
  begin
    insert into storage.objects (bucket_id, name) values ('materials', 'rls-test/admin-upload.pdf');
    r := r || E'\n' || 'PASS | [admin] Can upload files';
  exception when others then
    r := r || E'\n' || 'FAIL | [admin] Can upload files (' || sqlerrm || ')';
  end;

  execute 'reset role';

  -- Undo everything and hand back the report.
  raise exception 'RLS TEST REPORT (all changes rolled back)%', r;
end;
$test$;
