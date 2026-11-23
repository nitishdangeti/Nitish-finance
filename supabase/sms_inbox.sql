-- Payment inbox for bank SMS: the iPhone automation drops each bank SMS here (works even when the phone is locked),
-- and the site shows it under "To review" until you approve it. Safe to run more than once.

-- 1. The inbox: one row per bank SMS waiting for review. Only you can see or delete your rows.
create table if not exists public.sms_inbox (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  sms text not null,
  ref text,
  received_at timestamptz not null default now()
);
create unique index if not exists sms_inbox_user_ref_idx on public.sms_inbox(user_id, ref) where ref is not null;
alter table public.sms_inbox enable row level security;
drop policy if exists "own inbox" on public.sms_inbox;
create policy "own inbox" on public.sms_inbox for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 2. Your private iPhone key, stored only as a SHA-256 hash. The site creates it under Settings > iPhone SMS setup.
create table if not exists public.inbox_keys (
  user_id uuid primary key references auth.users(id) on delete cascade,
  key_hash text not null,
  created_at timestamptz not null default now()
);
alter table public.inbox_keys enable row level security;
drop policy if exists "own inbox key" on public.inbox_keys;
create policy "own inbox key" on public.inbox_keys for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 3. The only way in from the iPhone: add one SMS to the inbox of whoever owns the key. It can't read anything.
create or replace function public.add_sms(p_key text, p_sms text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_ref text;
begin
  select user_id into v_user from public.inbox_keys
   where key_hash = encode(sha256(convert_to(coalesce(p_key, ''), 'UTF8')), 'hex');
  if v_user is null then return 'wrong key'; end if;
  if p_sms is null or length(p_sms) < 15 or length(p_sms) > 1000 then return 'not a bank sms'; end if;
  v_ref := substring(p_sms from '(?i)(?:UPI\s*Ref(?:\s*No)?|Ref\s*No|by\s+MB)\s*[:.#]?\s*(\d{6,})');
  insert into public.sms_inbox(user_id, sms, ref) values (v_user, p_sms, v_ref)
  on conflict do nothing;                          -- the same SMS twice is kept once
  return 'ok';
end;
$$;
revoke all on function public.add_sms(text, text) from public;
grant execute on function public.add_sms(text, text) to anon, authenticated;
