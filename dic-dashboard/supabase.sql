-- ============================================================
-- DIC Startup Portfolio — Supabase SQL Schema
-- Run this entire file in Supabase SQL Editor (once)
-- ============================================================

-- ── 1. EXTENSIONS ──────────────────────────────────────────
create extension if not exists "uuid-ossp";

-- ── 2. ENUMS ───────────────────────────────────────────────
create type user_role      as enum ('startup', 'staff', 'admin');
create type risk_level     as enum ('Low', 'Medium', 'High', 'No Update');
create type startup_stage  as enum ('Idea', 'MVP', 'Early Revenue', 'Growth', 'Scale');
create type startup_status as enum ('Active', 'Graduated', 'Paused', 'Dropped', 'Dormant');
create type verify_status  as enum ('Verified', 'Reviewed', 'Needs Evidence', 'Unverified');
create type milestone_status as enum ('Not Started', 'In Progress', 'Completed', 'Delayed', 'Blocked');
create type funding_status as enum ('Received', 'Committed', 'In Negotiation', 'Closed', 'None');

-- ── 3. PROFILES (extends auth.users) ───────────────────────
create table public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  role        user_role not null default 'startup',
  display_name text,
  startup_id  uuid,   -- filled for role=startup, null for staff/admin
  created_at  timestamptz default now()
);
alter table public.profiles enable row level security;

-- ── 4. STARTUPS ────────────────────────────────────────────
create table public.startups (
  id              uuid primary key default uuid_generate_v4(),
  dic_id          text unique not null,          -- e.g. DIC-2024-001
  name            text not null,
  founder_name    text,
  program_owner   text,
  cohort          text,                          -- 'Cohort 2024' etc.
  program         text,                          -- Idea Camp / Incubation …
  sector          text,
  stage           startup_stage,
  status          startup_status default 'Active',
  risk_level      risk_level default 'No Update',
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);
alter table public.startups enable row level security;

-- ── 5. MONTHLY PERFORMANCE ─────────────────────────────────
create table public.monthly_performance (
  id                uuid primary key default uuid_generate_v4(),
  startup_id        uuid not null references public.startups(id) on delete cascade,
  reporting_month   date not null,               -- first day of month
  monthly_revenue   numeric default 0,
  mrr               numeric default 0,
  arr               numeric default 0,
  customers         int default 0,
  active_users      int default 0,
  pilots            int default 0,
  contracts         int default 0,
  burn_rate         numeric default 0,
  runway_months     int default 0,
  achievements      text,
  blockers          text,
  submitted_by      uuid references auth.users(id),
  submitted_at      timestamptz default now(),
  unique (startup_id, reporting_month)
);
alter table public.monthly_performance enable row level security;

-- ── 6. JOBS ────────────────────────────────────────────────
create table public.jobs (
  id              uuid primary key default uuid_generate_v4(),
  startup_id      uuid not null references public.startups(id) on delete cascade,
  reporting_month date not null,
  fulltime        int default 0,
  parttime        int default 0,
  interns         int default 0,
  contractors     int default 0,
  new_this_month  int default 0,
  qatar_based     int default 0,
  remote          int default 0,
  submitted_by    uuid references auth.users(id),
  submitted_at    timestamptz default now(),
  unique (startup_id, reporting_month)
);
alter table public.jobs enable row level security;

-- ── 7. FUNDING ─────────────────────────────────────────────
create table public.funding (
  id              uuid primary key default uuid_generate_v4(),
  startup_id      uuid not null references public.startups(id) on delete cascade,
  funding_status  funding_status default 'None',
  amount_received numeric default 0,
  amount_committed numeric default 0,
  round_type      text,
  source          text,
  funding_date    date,
  evidence        text,
  submitted_by    uuid references auth.users(id),
  submitted_at    timestamptz default now()
);
alter table public.funding enable row level security;

-- ── 8. MILESTONES ──────────────────────────────────────────
create table public.milestones (
  id              uuid primary key default uuid_generate_v4(),
  startup_id      uuid not null references public.startups(id) on delete cascade,
  name            text not null,
  category        text,
  target_date     date,
  status          milestone_status default 'Not Started',
  progress_pct    int default 0 check (progress_pct between 0 and 100),
  evidence        text,
  created_by      uuid references auth.users(id),  -- admin only
  updated_by      uuid references auth.users(id),
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);
alter table public.milestones enable row level security;

-- ── 9. PROGRAM ENGAGEMENT ──────────────────────────────────
create table public.engagement (
  id                  uuid primary key default uuid_generate_v4(),
  startup_id          uuid not null references public.startups(id) on delete cascade,
  reporting_month     date not null,
  mentoring_hours     int default 0,
  workshops_attended  int default 0,
  clinics_attended    int default 0,
  investor_meetings   int default 0,
  introductions_made  int default 0,
  satisfaction_score  int check (satisfaction_score between 1 and 10),
  benefits_used       text,
  program_comments    text,
  submitted_by        uuid references auth.users(id),
  submitted_at        timestamptz default now(),
  unique (startup_id, reporting_month)
);
alter table public.engagement enable row level security;

-- ── 10. STAFF VERIFICATION ─────────────────────────────────
create table public.verifications (
  id                  uuid primary key default uuid_generate_v4(),
  startup_id          uuid not null references public.startups(id) on delete cascade,
  reporting_month     date not null,
  reviewed_by         text,
  review_date         date,
  verify_status       verify_status default 'Unverified',
  intervention        text,
  action_owner        text,
  action_due_date     date,
  staff_notes         text,
  submitted_by        uuid references auth.users(id),
  submitted_at        timestamptz default now(),
  unique (startup_id, reporting_month)
);
alter table public.verifications enable row level security;

-- ── 11. SUPPORT REQUIRED ───────────────────────────────────
create table public.support_requests (
  id              uuid primary key default uuid_generate_v4(),
  startup_id      uuid not null references public.startups(id) on delete cascade,
  reporting_month date not null,
  support_type    text,
  detailed_blockers text,
  submitted_by    uuid references auth.users(id),
  submitted_at    timestamptz default now(),
  unique (startup_id, reporting_month)
);
alter table public.support_requests enable row level security;

-- ============================================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================================

-- Helper: get current user role
create or replace function public.get_my_role()
returns user_role language sql security definer stable as $$
  select role from public.profiles where id = auth.uid();
$$;

-- Helper: get current user's startup_id
create or replace function public.get_my_startup_id()
returns uuid language sql security definer stable as $$
  select startup_id from public.profiles where id = auth.uid();
$$;

-- ── PROFILES ──
create policy "Users can read own profile"
  on public.profiles for select using (id = auth.uid());
create policy "Admin can read all profiles"
  on public.profiles for select using (public.get_my_role() = 'admin');
create policy "Admin can insert profiles"
  on public.profiles for insert with check (public.get_my_role() = 'admin');
create policy "Admin can update profiles"
  on public.profiles for update using (public.get_my_role() = 'admin');

-- ── STARTUPS ──
create policy "Anyone can read startups (dashboard is public)"
  on public.startups for select using (true);
create policy "Staff and admin can insert startups"
  on public.startups for insert with check (public.get_my_role() in ('staff','admin'));
create policy "Staff and admin can update startups"
  on public.startups for update using (public.get_my_role() in ('staff','admin'));
create policy "Admin can delete startups"
  on public.startups for delete using (public.get_my_role() = 'admin');

-- ── MONTHLY PERFORMANCE ──
create policy "Dashboard: anyone reads performance"
  on public.monthly_performance for select using (true);
create policy "Startup reads own performance"
  on public.monthly_performance for select using (
    startup_id = public.get_my_startup_id() or public.get_my_role() in ('staff','admin')
  );
create policy "Startup inserts own performance"
  on public.monthly_performance for insert with check (
    startup_id = public.get_my_startup_id() or public.get_my_role() in ('staff','admin')
  );
create policy "Startup updates own performance"
  on public.monthly_performance for update using (
    startup_id = public.get_my_startup_id() or public.get_my_role() in ('staff','admin')
  );

-- ── JOBS ──
create policy "Anyone reads jobs" on public.jobs for select using (true);
create policy "Startup or staff inserts jobs" on public.jobs for insert with check (
  startup_id = public.get_my_startup_id() or public.get_my_role() in ('staff','admin'));
create policy "Startup or staff updates jobs" on public.jobs for update using (
  startup_id = public.get_my_startup_id() or public.get_my_role() in ('staff','admin'));

-- ── FUNDING ──
create policy "Anyone reads funding" on public.funding for select using (true);
create policy "Startup or staff inserts funding" on public.funding for insert with check (
  startup_id = public.get_my_startup_id() or public.get_my_role() in ('staff','admin'));
create policy "Startup or staff updates funding" on public.funding for update using (
  startup_id = public.get_my_startup_id() or public.get_my_role() in ('staff','admin'));

-- ── MILESTONES ──
create policy "Anyone reads milestones" on public.milestones for select using (true);
create policy "Admin creates milestones" on public.milestones for insert with check (
  public.get_my_role() = 'admin');
create policy "Startup updates own milestone progress" on public.milestones for update using (
  startup_id = public.get_my_startup_id() or public.get_my_role() in ('staff','admin'));
create policy "Admin deletes milestones" on public.milestones for delete using (
  public.get_my_role() = 'admin');

-- ── ENGAGEMENT ──
create policy "Anyone reads engagement" on public.engagement for select using (true);
create policy "Startup or staff inserts engagement" on public.engagement for insert with check (
  startup_id = public.get_my_startup_id() or public.get_my_role() in ('staff','admin'));
create policy "Startup or staff updates engagement" on public.engagement for update using (
  startup_id = public.get_my_startup_id() or public.get_my_role() in ('staff','admin'));

-- ── VERIFICATIONS (staff/admin only write) ──
create policy "Anyone reads verifications" on public.verifications for select using (true);
create policy "Staff or admin inserts verifications" on public.verifications for insert with check (
  public.get_my_role() in ('staff','admin'));
create policy "Staff or admin updates verifications" on public.verifications for update using (
  public.get_my_role() in ('staff','admin'));

-- ── SUPPORT REQUESTS ──
create policy "Staff/admin reads support" on public.support_requests for select using (
  startup_id = public.get_my_startup_id() or public.get_my_role() in ('staff','admin'));
create policy "Startup or staff inserts support" on public.support_requests for insert with check (
  startup_id = public.get_my_startup_id() or public.get_my_role() in ('staff','admin'));
create policy "Startup or staff updates support" on public.support_requests for update using (
  startup_id = public.get_my_startup_id() or public.get_my_role() in ('staff','admin'));

-- ============================================================
-- REALTIME: enable live updates for dashboard
-- ============================================================
alter publication supabase_realtime add table public.startups;
alter publication supabase_realtime add table public.monthly_performance;
alter publication supabase_realtime add table public.jobs;
alter publication supabase_realtime add table public.funding;
alter publication supabase_realtime add table public.milestones;
alter publication supabase_realtime add table public.verifications;

-- ============================================================
-- SEED DATA — 12 startups + sample monthly data
-- Run AFTER creating auth users and updating UUIDs below
-- ============================================================

insert into public.startups (dic_id, name, founder_name, program_owner, cohort, program, sector, stage, status, risk_level) values
  ('DIC-2024-001','NovaPay','Ahmed Khalid','Layla Hassan','Cohort 2024','Incubation','FinTech','Early Revenue','Active','Low'),
  ('DIC-2024-002','EduPath','Sara Al-Rashid','Omar Jassim','Cohort 2024','Go-To-Market','EdTech','Growth','Active','Low'),
  ('DIC-2024-003','MedTrack','Khalid Nasser','Layla Hassan','Cohort 2024','Incubation','HealthTech','MVP','Active','High'),
  ('DIC-2024-004','GovLink','Fatima Al-Ali','Omar Jassim','Cohort 2024','Investor Readiness','GovTech','Early Revenue','Active','Low'),
  ('DIC-2025-001','AgroSense','Mohammed Yusuf','Ahmed Khalid','Cohort 2025','Incubation','AI','MVP','Active','Medium'),
  ('DIC-2025-002','CloudStack QA','Noor Al-Mansouri','Ahmed Khalid','Cohort 2025','Go-To-Market','SaaS','Early Revenue','Active','Low'),
  ('DIC-2025-003','HealthBot','Reem Jaber','Layla Hassan','Cohort 2025','Idea Camp','HealthTech','Idea','Active','High'),
  ('DIC-2025-004','FinSight','Tariq Al-Hamad','Omar Jassim','Cohort 2025','Investor Readiness','FinTech','Growth','Active','Low'),
  ('DIC-2026-001','SmartPort','Hessa Al-Kuwari','Ahmed Khalid','Cohort 2026','Incubation','AI','MVP','Active','Medium'),
  ('DIC-2026-002','RetailIQ','Jassim Mohammed','Layla Hassan','Cohort 2026','Idea Camp','SaaS','Idea','Active','Medium'),
  ('DIC-2026-003','CivicAI','Dana Al-Thani','Omar Jassim','Cohort 2026','Incubation','GovTech','MVP','Active','Medium'),
  ('DIC-2026-004','LogiFlow','Saad Al-Emadi','Ahmed Khalid','Cohort 2026','Incubation','AI','MVP','Active','Medium');
