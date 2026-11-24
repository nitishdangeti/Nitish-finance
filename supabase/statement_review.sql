-- Statement uploads: remember which PDF upload each transaction came from (so a whole upload can be deleted at once),
-- and hold big entries (over ₹5,000) for you to confirm before they count. Safe to run more than once.
alter table public.transactions add column if not exists import_batch text;                       -- "<file name> · <when>#<id>"
alter table public.transactions add column if not exists needs_review boolean not null default false;
create index if not exists transactions_import_batch_idx on public.transactions(user_id, import_batch) where import_batch is not null;
