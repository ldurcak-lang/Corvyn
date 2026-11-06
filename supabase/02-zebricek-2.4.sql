-- Corvyn 2.4 – rozšíření žebříčku: Lovkyně, trhliny, týdenní boss, hardcore, filtr jmen, nahlášení
alter table public.scores drop constraint if exists scores_cls_check;
alter table public.scores add constraint scores_cls_check check (cls in ('necro','barbar','mag','zlobr','lovec'));
alter table public.scores add column if not exists rift int not null default 0;
alter table public.scores add column if not exists wk int not null default 0;
alter table public.scores add column if not exists wk_time int not null default 0;
alter table public.scores add column if not exists hc boolean not null default false;
alter table public.scores add column if not exists hidden boolean not null default false;

create table if not exists public.reports (
  id bigserial primary key,
  reporter text not null,
  name text not null,
  cls text,
  created timestamptz not null default now()
);
alter table public.reports enable row level security;
revoke all on public.reports from anon, authenticated;

create or replace function public.name_ok(n text) returns boolean language sql immutable as $$
  select not (translate(lower(coalesce(n,'')), 'áčďéěíňóřšťúůýžñ013457@$', 'acdeeinorstuuyznoieastas')
    ~ '(kurv|pica|pico|pice|picu|kokot|curak|mrdk|mrdat|jebat|jebe|zmrd|buzna|buzerant|negr|cikan|fuck|shit|bitch|cunt|dick|cock|pussy|nigg|fagg|whore|slut|rape|hitler|nazi|puta|puto|mierda|polla|verga|pendejo|cabron|maricon|joder|gilipollas|zorra)')
$$;

drop function if exists public.submit_score(text,text,text,int,int,int,int,int,int);
create or replace function public.submit_score(
  p_secret text, p_cls text, p_name text, p_emblem int, p_level int,
  p_ng int, p_kobka int, p_kills int, p_chapter int,
  p_rift int default 0, p_wk int default 0, p_wk_time int default 0, p_hc boolean default false)
returns void language plpgsql security definer set search_path = public as $$
declare o text := md5(coalesce(p_secret,''));
declare lv int := least(greatest(p_level,1),99);
declare ng int := least(greatest(p_ng,0),2);
declare ch int := least(greatest(p_chapter,1),4);
declare kb int := least(greatest(p_kobka,1),999);
declare kl int := least(greatest(p_kills,0),10000000);
declare rf int := least(greatest(coalesce(p_rift,0),0),999);
begin
  if char_length(coalesce(p_secret,'')) < 8 then return; end if;
  if char_length(trim(coalesce(p_name,''))) < 2 or not public.name_ok(p_name) then return; end if;
  insert into scores(owner,cls,name,emblem,level,ng,kobka,kills,chapter,score,rift,wk,wk_time,hc,updated)
  values (o, p_cls, left(trim(p_name),20), least(greatest(p_emblem,0),99), lv, ng, kb, kl, ch,
          lv*1000 + ng*100000 + ch*5000 + kb*500 + kl/10 + rf*2000,
          rf, greatest(coalesce(p_wk,0),0), least(greatest(coalesce(p_wk_time,0),0),36000), coalesce(p_hc,false), now())
  on conflict (owner, cls) do update set
    name=excluded.name, emblem=excluded.emblem, level=excluded.level, ng=excluded.ng,
    kobka=excluded.kobka, kills=excluded.kills, chapter=excluded.chapter, score=excluded.score,
    rift=excluded.rift, wk=excluded.wk, wk_time=excluded.wk_time, hc=excluded.hc, updated=now();
end $$;
revoke all on function public.submit_score(text,text,text,int,int,int,int,int,int,int,int,int,boolean) from public;
grant execute on function public.submit_score(text,text,text,int,int,int,int,int,int,int,int,int,boolean) to anon, authenticated;

create or replace function public.report_player(p_secret text, p_name text, p_cls text)
returns void language plpgsql security definer set search_path = public as $$
declare o text := md5(coalesce(p_secret,''));
begin
  if char_length(coalesce(p_secret,'')) < 8 then return; end if;
  if (select count(*) from reports where reporter=o and created > now() - interval '1 day') >= 20 then return; end if;
  if exists (select 1 from reports where reporter=o and name=left(p_name,20)) then return; end if;
  insert into reports(reporter, name, cls) values (o, left(coalesce(p_name,''),20), left(coalesce(p_cls,''),10));
end $$;
revoke all on function public.report_player(text,text,text) from public;
grant execute on function public.report_player(text,text,text) to anon, authenticated;

-- jméno nahlášené třemi různými hráči nebo ručně skryté se v žebříčku neukáže
create or replace view public.leaderboard with (security_invoker = false) as
  select s.name, s.cls, s.emblem, s.level, s.ng, s.kobka, s.kills, s.chapter, s.score, s.updated, s.rift, s.wk, s.wk_time, s.hc
  from public.scores s
  where not s.hidden and public.name_ok(s.name)
    and (select count(distinct r.reporter) from public.reports r where r.name = s.name) < 3;
grant select on public.leaderboard to anon, authenticated;
