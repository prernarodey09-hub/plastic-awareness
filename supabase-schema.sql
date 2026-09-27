create table if not exists public.quiz_results (
  attempt_id uuid primary key default gen_random_uuid(),
  participant_id uuid not null,
  display_name text not null check (char_length(display_name) between 1 and 70),
  score smallint not null check (score between 0 and 100),
  certificate_generated boolean not null default false,
  completed_at timestamptz not null default now()
);

alter table public.quiz_results enable row level security;

drop policy if exists "Public can read quiz results" on public.quiz_results;
create policy "Public can read quiz results"
  on public.quiz_results for select to anon using (true);

drop policy if exists "Public can submit quiz results" on public.quiz_results;
create policy "Public can submit quiz results"
  on public.quiz_results for insert to anon
  with check (
    char_length(display_name) between 1 and 70
    and score between 0 and 100
  );

drop policy if exists "Public can mark generated certificates" on public.quiz_results;
create policy "Public can mark generated certificates"
  on public.quiz_results for update to anon
  using (true)
  with check (
    char_length(display_name) between 1 and 70
    and score between 0 and 100
  );

grant select, insert on public.quiz_results to anon;
grant update (certificate_generated) on public.quiz_results to anon;

create or replace function public.get_public_quiz_dashboard()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'participants', count(distinct participant_id),
    'attempts', count(*),
    'certificates', count(*) filter (where certificate_generated),
    'average', round(avg(score)),
    'results', coalesce((
      select jsonb_agg(to_jsonb(recent) order by recent.completed_at desc)
      from (
        select attempt_id, participant_id, display_name, score, certificate_generated, completed_at
        from public.quiz_results
        order by completed_at desc
        limit 100
      ) as recent
    ), '[]'::jsonb)
  )
  from public.quiz_results;
$$;

grant execute on function public.get_public_quiz_dashboard() to anon;