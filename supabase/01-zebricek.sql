create table if not exists public.scores (
  owner   text not null,
  cls     text not null check (cls in ('necro','barbar','mag','zlobr')),
  name    text not null check (char_length(name) between 1 and 20),
  emblem  int  not null default 0,
  level   int  not null default 1,
  ng      int  not null default 0,
  kobka   int  not null default 1,
  kills   int  not null default 0,
  chapter int  not null default 1,
  score   bigint not null default 0,
  updated timestamptz not null default now(),
  primary key (owner, cls)
);
alter table public.scores enable row level security;
revoke all on public.scores from anon, authenticated;

create or replace function public.submit_score(
  p_secret text, p_cls text, p_name text, p_emblem int, p_level int,
  p_ng int, p_kobka int, p_kills int, p_chapter int)
returns void language plpgsql security definer set search_path = public as $$
declare o text := md5(coalesce(p_secret,''));
begin
  if char_length(coalesce(p_secret,'')) < 8 then return; end if;
  insert into scores(owner,cls,name,emblem,level,ng,kobka,kills,chapter,score,updated)
  values (o, p_cls, left(trim(p_name),20), least(greatest(p_emblem,0),99),
          least(greatest(p_level,1),99), least(greatest(p_ng,0),2),
          least(greatest(p_kobka,1),999), least(greatest(p_kills,0),10000000),
          least(greatest(p_chapter,1),4),
          least(greatest(p_level,1),99)*1000 + least(greatest(p_ng,0),2)*100000
            + least(greatest(p_chapter,1),4)*5000 + least(greatest(p_kobka,1),999)*500
            + least(greatest(p_kills,0),10000000)/10, now())
  on conflict (owner, cls) do update set
    name=excluded.name, emblem=excluded.emblem, level=excluded.level, ng=excluded.ng,
    kobka=excluded.kobka, kills=excluded.kills, chapter=excluded.chapter,
    score=excluded.score, updated=now();
end $$;
revoke all on function public.submit_score(text,text,text,int,int,int,int,int,int) from public;
grant execute on function public.submit_score(text,text,text,int,int,int,int,int,int) to anon, authenticated;

create or replace view public.leaderboard with (security_invoker = false) as
  select name, cls, emblem, level, ng, kobka, kills, chapter, score, updated from public.scores;
grant select on public.leaderboard to anon, authenticated;
