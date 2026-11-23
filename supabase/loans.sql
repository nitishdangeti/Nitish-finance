-- Loans & EMIs: one-time database update for the Finance Calculator.
-- Adds EMI details to loans and links each EMI payment to its loan.
-- Safe to run more than once. Existing data is not changed.

alter table public.debts
  add column if not exists kind text default 'Loan',
  add column if not exists emi_amount numeric,
  add column if not exists due_day smallint;

alter table public.debts drop constraint if exists debts_due_day_check;
alter table public.debts add constraint debts_due_day_check check (due_day is null or due_day between 1 and 31);

alter table public.transactions
  add column if not exists debt_id uuid references public.debts(id) on delete set null;

create index if not exists transactions_debt_id_idx on public.transactions(debt_id);
-- Row Level Security stays on: the existing "own debts" / "own transactions" policies cover the new columns.
