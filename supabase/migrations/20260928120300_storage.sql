-- Phase 2 · 4/4: private file storage for PDFs and worksheets.
-- Videos are NOT uploaded here — they are unlisted YouTube links
-- (materials.external_url).
--
-- The bucket is private: files have no public URL. The app gives students a
-- short-lived signed URL, which only works if the rules below allow them to
-- read the file.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'materials',
  'materials',
  false,
  20 * 1024 * 1024, -- 20 MB per file
  array[
    'application/pdf',
    'image/png',
    'image/jpeg',
    'image/webp',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',   -- .docx
    'application/vnd.openxmlformats-officedocument.presentationml.presentation', -- .pptx
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'          -- .xlsx
  ]
)
on conflict (id) do nothing;

-- True when the file at this path belongs to a material the current student
-- can see (assigned to one of their active/completed classes).
create function private.can_read_material_file(object_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.materials m
    where m.storage_path = object_path
      and m.id in (select private.my_material_ids())
  );
$$;

revoke all on function private.can_read_material_file(text) from public;
grant execute on function private.can_read_material_file(text) to authenticated;

create policy "Admins manage material files"
  on storage.objects for all to authenticated
  using (bucket_id = 'materials' and (select private.is_admin()))
  with check (bucket_id = 'materials' and (select private.is_admin()));

create policy "Students read files of their assigned materials"
  on storage.objects for select to authenticated
  using (bucket_id = 'materials' and private.can_read_material_file(name));
