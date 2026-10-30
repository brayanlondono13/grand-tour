-- The Grand Tour (Sandra's 50th, Bray's 30th): interest responses.
-- Runs in the Breckenridge Supabase project next to that trip's tables; everything here is prefixed gt_.
-- Re-running it is safe. The planner PIN is the Breckenridge one (settings.pin, checked by planner_verify).

create table if not exists gt_responses (
  person      text primary key,
  answer      text not null check (answer in ('in', 'maybe', 'no')),
  budget      text check (budget in ('comfortable', 'stretch', 'lower')),
  extras      text[] not null default '{}',
  note        text,
  updated_at  timestamptz not null default now()
);

-- Answers are private: no policies, so the public key can't read or write the table directly.
alter table gt_responses enable row level security;
revoke all on gt_responses from anon, authenticated;

-- The brochure only ever shows who said yes. Maybes, no's, budgets and notes stay private.
create or replace view gt_yes as
  select person from gt_responses where answer = 'in';
grant select on gt_yes to anon, authenticated;

-- Everyone on the invite list. Ali answers through Bray's "same answer for Ali" box.
create or replace function gt_people()
returns text[] language sql immutable as $$
  select array['Sandra','Brian','Bray','Ali','Gloria','Jerry','Manny','Ivy','Luis','Anna',
               'Natalia','Anthony','Hailey','Dacian','Isaiah','Leah'];
$$;

create or replace function gt_respond(p_person text, p_answer text, p_budget text, p_extras text[], p_note text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (p_person = any (gt_people())) then raise exception 'unknown person %', p_person; end if;
  insert into gt_responses (person, answer, budget, extras, note, updated_at)
  values (p_person, p_answer, case when p_answer = 'no' then null else p_budget end,
          coalesce(p_extras, '{}'), nullif(trim(p_note), ''), now())
  on conflict (person) do update
    set answer = excluded.answer, budget = excluded.budget, extras = excluded.extras,
        note = excluded.note, updated_at = now();
  insert into change_log (text) values ('Grand Tour: ' || p_person || ' answered ' || p_answer);
end $$;

-- Lets a phone fill in the form with that person's last answer when they come back to change it.
create or replace function gt_my_response(p_person text)
returns setof gt_responses language sql security definer set search_path = public as $$
  select * from gt_responses where person = p_person;
$$;

-- Bray's view of every answer, PIN-gated like the Breckenridge planner.
create or replace function gt_planner_responses(p_pin text)
returns setof gt_responses language plpgsql security definer set search_path = public as $$
begin
  if not planner_verify(p_pin) then raise exception 'bad pin'; end if;
  return query select * from gt_responses order by updated_at desc;
end $$;

grant execute on function gt_respond(text, text, text, text[], text),
                          gt_my_response(text),
                          gt_planner_responses(text) to anon, authenticated;
