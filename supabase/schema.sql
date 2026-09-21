-- Rhino Tool Check — schema v2 (round 3 additions)
-- Run this ONCE in the Supabase SQL editor, after the original schema.sql/seed.sql
-- have already been run. Everything here is additive (IF NOT EXISTS / IF EXISTS
-- guards throughout) so it's safe to run even if part of it was already applied.

-- ── Tools: replace name-sniffing with an explicit type ──────────────────────
-- Drives: the editable expiry-date field (harness/extinguisher), the inline
-- "Inspect Ladder" button (ladder_extension/ladder_step8ft), and which tools
-- the Fire Extinguisher stage cycles through.
alter table tools add column if not exists tool_type text;
-- allowed values (enforced in the app, not a DB constraint, so it's easy to
-- extend later): null | 'harness' | 'extinguisher' | 'ladder_extension' | 'ladder_step8ft'

-- ── People & Tool Bags ───────────────────────────────────────────────────────
create table if not exists team_people (
  id         uuid primary key default gen_random_uuid(),
  team_id    uuid not null references teams(id) on delete cascade,
  name       text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists idx_people_team on team_people(team_id);

create table if not exists bag_tools (
  id            uuid primary key default gen_random_uuid(),
  person_id     uuid not null references team_people(id) on delete cascade,
  name          text not null,
  qty           text not null default '1',
  serial_number text not null default '',
  sort_order    int not null default 0,
  created_at    timestamptz not null default now()
);
create index if not exists idx_bagtools_person on bag_tools(person_id);

-- ── Checks: one row per completed check of ANY kind ─────────────────────────
alter table checks add column if not exists kind text not null default 'team';
  -- 'team' | 'toolbag' | 'first_aid' | 'fire_extinguisher' | 'ladder_extension' | 'ladder_step8ft'
alter table checks add column if not exists person_id uuid references team_people(id) on delete set null;       -- toolbag checks
alter table checks add column if not exists tool_ref_id uuid references tools(id) on delete set null;            -- ladder / extinguisher checks — which specific tool
alter table checks add column if not exists parent_check_id uuid references checks(id) on delete set null;      -- links back to the team check that led here (null if run standalone)
alter table checks add column if not exists outcome text;                                                        -- 'pass' | 'fail' — ladder/extinguisher inspections only
create index if not exists idx_checks_kind on checks(kind);

-- ── Check items: loosen the status list to cover First Aid Kit's "short" ────
alter table check_items drop constraint if exists check_items_status_check;
alter table check_items add constraint check_items_status_check
  check (status in ('present','missing','damaged','short'));
alter table check_items add column if not exists bag_tool_id uuid references bag_tools(id) on delete set null;  -- set for tool-bag check items instead of tool_id

-- ── Check points: one row per inspection POINT (ladders / fire extinguisher) ─
create table if not exists check_points (
  id          uuid primary key default gen_random_uuid(),
  check_id    uuid not null references checks(id) on delete cascade,
  group_label text not null,   -- e.g. "1. Labels & rating" or "Monthly Visual Inspection"
  point_label text not null,
  result      text not null check (result in ('ok','fail','na')),
  comment     text,
  sort_order  int not null default 0,
  created_at  timestamptz not null default now()
);
create index if not exists idx_check_points_check on check_points(check_id);

-- ── Row Level Security (same permissive convention as the rest of this app) ─
alter table team_people  enable row level security;
alter table bag_tools    enable row level security;
alter table check_points enable row level security;

create policy "anon full access" on team_people  for all using (true) with check (true);
create policy "anon full access" on bag_tools    for all using (true) with check (true);
create policy "anon full access" on check_points for all using (true) with check (true);

-- ── Realtime ─────────────────────────────────────────────────────────────────
alter publication supabase_realtime add table team_people;
alter publication supabase_realtime add table bag_tools;
alter publication supabase_realtime add table check_points;
