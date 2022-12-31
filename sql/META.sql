\pset tuples_only
\pset format unaligned

begin;

create extension pg_utility_trigger_functions
    cascade;

select jsonb_pretty(pg_utility_trigger_functions_meta_pgxn());

rollback;
