drop table if exists public.activity_logs   cascade;
drop table if exists public.attachments     cascade;
drop table if exists public.checklist_items cascade;
drop table if exists public.checklists      cascade;
drop table if exists public.comments        cascade;
drop table if exists public.card_labels     cascade;
drop table if exists public.labels          cascade;
drop table if exists public.card_members    cascade;
drop table if exists public.cards           cascade;
drop table if exists public.lists           cascade;
drop table if exists public.board_members   cascade;
drop table if exists public.boards          cascade;
drop table if exists public.workspace_members cascade;
drop table if exists public.workspaces      cascade;
drop table if exists public.profiles        cascade;

drop type if exists public.member_role cascade;
create type public.member_role as enum ('owner', 'admin', 'member', 'viewer');

create table public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text,
  username    text unique,
  avatar_url  text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.workspaces (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  description text,
  owner_id    uuid not null references public.profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.workspace_members (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id      uuid not null references public.profiles(id)   on delete cascade,
  role         public.member_role not null default 'member',
  joined_at    timestamptz not null default now(),
  primary key (workspace_id, user_id)
);

create table public.boards (
  id           uuid primary key default gen_random_uuid(),
  workspace_id uuid references public.workspaces(id) on delete cascade,
  title        text not null,
  description  text,
  background   text default '#0079bf',
  visibility   text not null default 'private'
               check (visibility in ('private', 'workspace', 'public')),
  is_archived  boolean not null default false,
  created_by   uuid not null references public.profiles(id) on delete cascade,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table public.board_members (
  board_id  uuid not null references public.boards(id)   on delete cascade,
  user_id   uuid not null references public.profiles(id) on delete cascade,
  role      public.member_role not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (board_id, user_id)
);

create table public.lists (
  id          uuid primary key default gen_random_uuid(),
  board_id    uuid not null references public.boards(id) on delete cascade,
  title       text not null,
  position    double precision not null default 0,
  is_archived boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.cards (
  id           uuid primary key default gen_random_uuid(),
  list_id      uuid not null references public.lists(id)  on delete cascade,
  board_id     uuid not null references public.boards(id) on delete cascade,
  title        text not null,
  description  text,
  position     double precision not null default 0,
  start_date   timestamptz,
  due_date     timestamptz,
  is_completed boolean not null default false,
  priority     text default 'medium'
               check (priority in ('low', 'medium', 'high', 'urgent')),
  cover_color  text,
  is_archived  boolean not null default false,
  created_by   uuid references public.profiles(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table public.card_members (
  card_id     uuid not null references public.cards(id)    on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  assigned_at timestamptz not null default now(),
  primary key (card_id, user_id)
);

create table public.labels (
  id       uuid primary key default gen_random_uuid(),
  board_id uuid not null references public.boards(id) on delete cascade,
  name     text,
  color    text not null default '#61bd4f'
);

create table public.card_labels (
  card_id  uuid not null references public.cards(id)  on delete cascade,
  label_id uuid not null references public.labels(id) on delete cascade,
  primary key (card_id, label_id)
);

create table public.comments (
  id         uuid primary key default gen_random_uuid(),
  card_id    uuid not null references public.cards(id)    on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  content    text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.checklists (
  id         uuid primary key default gen_random_uuid(),
  card_id    uuid not null references public.cards(id) on delete cascade,
  title      text not null default 'Checklist',
  position   double precision not null default 0,
  created_at timestamptz not null default now()
);

create table public.checklist_items (
  id           uuid primary key default gen_random_uuid(),
  checklist_id uuid not null references public.checklists(id) on delete cascade,
  content      text not null,
  is_checked   boolean not null default false,
  position     double precision not null default 0,
  created_at   timestamptz not null default now()
);

create table public.attachments (
  id          uuid primary key default gen_random_uuid(),
  card_id     uuid not null references public.cards(id) on delete cascade,
  uploaded_by uuid references public.profiles(id) on delete set null,
  file_name   text not null,
  file_url    text not null,
  file_size   bigint,
  mime_type   text,
  created_at  timestamptz not null default now()
);

create table public.activity_logs (
  id         uuid primary key default gen_random_uuid(),
  board_id   uuid not null references public.boards(id) on delete cascade,
  card_id    uuid references public.cards(id) on delete cascade,
  user_id    uuid references public.profiles(id) on delete set null,
  action     text not null,
  details    jsonb,
  created_at timestamptz not null default now()
);

create index on public.boards        (workspace_id);
create index on public.board_members (user_id);
create index on public.lists         (board_id, position);
create index on public.cards         (list_id, position);
create index on public.cards         (board_id);
create index on public.card_members  (user_id);
create index on public.labels        (board_id);
create index on public.comments      (card_id);
create index on public.checklists    (card_id);
create index on public.checklist_items (checklist_id);
create index on public.attachments   (card_id);
create index on public.activity_logs (board_id, created_at desc);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

create trigger trg_profiles_updated   before update on public.profiles   for each row execute function public.set_updated_at();
create trigger trg_workspaces_updated before update on public.workspaces for each row execute function public.set_updated_at();
create trigger trg_boards_updated     before update on public.boards     for each row execute function public.set_updated_at();
create trigger trg_lists_updated      before update on public.lists      for each row execute function public.set_updated_at();
create trigger trg_cards_updated      before update on public.cards      for each row execute function public.set_updated_at();
create trigger trg_comments_updated   before update on public.comments   for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (new.id,
          new.raw_user_meta_data ->> 'full_name',
          new.raw_user_meta_data ->> 'avatar_url');
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.add_board_owner()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.board_members (board_id, user_id, role)
  values (new.id, new.created_by, 'owner');
  return new;
end $$;

create trigger trg_board_owner
  after insert on public.boards
  for each row execute function public.add_board_owner();

create or replace function public.add_workspace_owner()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.workspace_members (workspace_id, user_id, role)
  values (new.id, new.owner_id, 'owner');
  return new;
end $$;

create trigger trg_workspace_owner
  after insert on public.workspaces
  for each row execute function public.add_workspace_owner();

create or replace function public.is_board_member(b_id uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select exists (select 1 from board_members
                 where board_id = b_id and user_id = auth.uid());
$$;

create or replace function public.is_board_admin(b_id uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select exists (select 1 from board_members
                 where board_id = b_id and user_id = auth.uid()
                   and role in ('owner', 'admin'));
$$;

create or replace function public.is_workspace_member(w_id uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select exists (select 1 from workspace_members
                 where workspace_id = w_id and user_id = auth.uid());
$$;

create or replace function public.card_board(c_id uuid)
returns uuid language sql security definer stable set search_path = public as $$
  select board_id from cards where id = c_id;
$$;

alter table public.profiles          enable row level security;
alter table public.workspaces        enable row level security;
alter table public.workspace_members enable row level security;
alter table public.boards            enable row level security;
alter table public.board_members     enable row level security;
alter table public.lists             enable row level security;
alter table public.cards             enable row level security;
alter table public.card_members      enable row level security;
alter table public.labels            enable row level security;
alter table public.card_labels       enable row level security;
alter table public.comments          enable row level security;
alter table public.checklists        enable row level security;
alter table public.checklist_items   enable row level security;
alter table public.attachments       enable row level security;
alter table public.activity_logs     enable row level security;

create policy "profiles_select" on public.profiles for select to authenticated using (true);
create policy "profiles_update" on public.profiles for update to authenticated using (id = auth.uid());

create policy "ws_select" on public.workspaces for select to authenticated
  using (public.is_workspace_member(id) or owner_id = auth.uid());
create policy "ws_insert" on public.workspaces for insert to authenticated
  with check (owner_id = auth.uid());
create policy "ws_update" on public.workspaces for update to authenticated
  using (owner_id = auth.uid());
create policy "ws_delete" on public.workspaces for delete to authenticated
  using (owner_id = auth.uid());

create policy "wsm_select" on public.workspace_members for select to authenticated
  using (public.is_workspace_member(workspace_id));
create policy "wsm_manage" on public.workspace_members for all to authenticated
  using (exists (select 1 from public.workspaces w where w.id = workspace_id and w.owner_id = auth.uid()))
  with check (exists (select 1 from public.workspaces w where w.id = workspace_id and w.owner_id = auth.uid()));

create policy "boards_select" on public.boards for select to authenticated
  using (public.is_board_member(id)
         or visibility = 'public'
         or (visibility = 'workspace' and public.is_workspace_member(workspace_id)));
create policy "boards_insert" on public.boards for insert to authenticated
  with check (created_by = auth.uid());
create policy "boards_update" on public.boards for update to authenticated
  using (public.is_board_admin(id));
create policy "boards_delete" on public.boards for delete to authenticated
  using (public.is_board_admin(id));

create policy "bm_select" on public.board_members for select to authenticated
  using (public.is_board_member(board_id));
create policy "bm_insert" on public.board_members for insert to authenticated
  with check (public.is_board_admin(board_id));
create policy "bm_update" on public.board_members for update to authenticated
  using (public.is_board_admin(board_id));
create policy "bm_delete" on public.board_members for delete to authenticated
  using (public.is_board_admin(board_id) or user_id = auth.uid());

create policy "lists_all"  on public.lists  for all to authenticated
  using (public.is_board_member(board_id)) with check (public.is_board_member(board_id));
create policy "cards_all"  on public.cards  for all to authenticated
  using (public.is_board_member(board_id)) with check (public.is_board_member(board_id));
create policy "labels_all" on public.labels for all to authenticated
  using (public.is_board_member(board_id)) with check (public.is_board_member(board_id));
create policy "activity_select" on public.activity_logs for select to authenticated
  using (public.is_board_member(board_id));
create policy "activity_insert" on public.activity_logs for insert to authenticated
  with check (public.is_board_member(board_id) and user_id = auth.uid());

create policy "card_members_all" on public.card_members for all to authenticated
  using (public.is_board_member(public.card_board(card_id)))
  with check (public.is_board_member(public.card_board(card_id)));
create policy "card_labels_all" on public.card_labels for all to authenticated
  using (public.is_board_member(public.card_board(card_id)))
  with check (public.is_board_member(public.card_board(card_id)));
create policy "checklists_all" on public.checklists for all to authenticated
  using (public.is_board_member(public.card_board(card_id)))
  with check (public.is_board_member(public.card_board(card_id)));
create policy "attachments_all" on public.attachments for all to authenticated
  using (public.is_board_member(public.card_board(card_id)))
  with check (public.is_board_member(public.card_board(card_id)));

create policy "checklist_items_all" on public.checklist_items for all to authenticated
  using (exists (select 1 from public.checklists c
                 where c.id = checklist_id and public.is_board_member(public.card_board(c.card_id))))
  with check (exists (select 1 from public.checklists c
                 where c.id = checklist_id and public.is_board_member(public.card_board(c.card_id))));

create policy "comments_select" on public.comments for select to authenticated
  using (public.is_board_member(public.card_board(card_id)));
create policy "comments_insert" on public.comments for insert to authenticated
  with check (user_id = auth.uid() and public.is_board_member(public.card_board(card_id)));
create policy "comments_update" on public.comments for update to authenticated
  using (user_id = auth.uid());
create policy "comments_delete" on public.comments for delete to authenticated
  using (user_id = auth.uid());

alter publication supabase_realtime add table public.lists;
alter publication supabase_realtime add table public.cards;
alter publication supabase_realtime add table public.comments;
alter publication supabase_realtime add table public.checklist_items;
