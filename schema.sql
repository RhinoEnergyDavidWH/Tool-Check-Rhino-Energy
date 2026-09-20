-- Rhino Tool Check — database schema
-- Run this once in the Supabase project's SQL editor (Database > SQL Editor > New query),
-- before running seed.sql.

create extension if not exists pgcrypto;

-- ── Teams ─────────────────────────────────────────────────────────────────
create table if not exists teams (
  id           uuid primary key default gen_random_uuid(),
  slug         text unique not null,
  name         text not null,
  leader       text not null default '',
  members      text[] not null default array[]::text[],
  last_check_at date,
  created_at   timestamptz not null default now()
);

-- ── Tools (the master checklist per team) ───────────────────────────────────
create table if not exists tools (
  id            uuid primary key default gen_random_uuid(),
  team_id       uuid not null references teams(id) on delete cascade,
  name          text not null,
  qty           text not null default '1',
  serial_number text not null default '',
  category      text,
  expiry_date   date,               -- used for fire extinguishers / safety harnesses
  sort_order    int not null default 0,
  created_at    timestamptz not null default now()
);
create index if not exists idx_tools_team on tools(team_id);

-- ── Checks (one row per completed tool check) ───────────────────────────────
create table if not exists checks (
  id                 uuid primary key default gen_random_uuid(),
  team_id            uuid not null references teams(id) on delete cascade,
  check_date         date not null default current_date,
  leader_name        text not null default '',
  checker_name       text not null default '',
  checker_signature  text,   -- data URL (PNG) of the drawn signature
  leader_signature   text,   -- data URL (PNG) of the drawn signature
  created_at         timestamptz not null default now()
);
create index if not exists idx_checks_team_date on checks(team_id, check_date desc);

-- ── Check items (one row per tool inside a check) ───────────────────────────
create table if not exists check_items (
  id             uuid primary key default gen_random_uuid(),
  check_id       uuid not null references checks(id) on delete cascade,
  team_id        uuid not null references teams(id) on delete cascade, -- denormalised for fast replacement-report queries
  tool_id        uuid references tools(id) on delete set null,
  tool_name      text not null,
  qty            text not null default '1',
  serial_number  text not null default '',
  status         text not null check (status in ('present','missing','damaged')),
  note           text,
  replaced_at    timestamptz,   -- set when manually marked "Mark as Replaced"
  replaced_by    text,
  created_at     timestamptz not null default now()
);
create index if not exists idx_check_items_check on check_items(check_id);
create index if not exists idx_check_items_team_tool on check_items(team_id, tool_name, created_at desc);

-- ── Row Level Security ───────────────────────────────────────────────────
-- This app has no individual logins (matches the rest of the Rhino Energy
-- Solutions app suite) — both tablets connect with the same public anon key.
-- Access is protected by that key/URL not being published anywhere public,
-- not by per-user auth. If you later want to lock this down further (e.g.
-- restrict deletes), tighten these policies — they intentionally start
-- permissive so the app works out of the box.

alter table teams       enable row level security;
alter table tools       enable row level security;
alter table checks      enable row level security;
alter table check_items enable row level security;

create policy "anon full access" on teams
  for all using (true) with check (true);
create policy "anon full access" on tools
  for all using (true) with check (true);
create policy "anon full access" on checks
  for all using (true) with check (true);
create policy "anon full access" on check_items
  for all using (true) with check (true);

-- ── Realtime (so both tablets see new checks / teams live) ────────────────
alter publication supabase_realtime add table teams;
alter publication supabase_realtime add table tools;
alter publication supabase_realtime add table checks;
alter publication supabase_realtime add table check_items;
