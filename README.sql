\pset tuples_only
\pset format unaligned

begin;

create schema if not exists ext;

create extension pg_utility_trigger_functions
    with schema ext
    cascade;

select ext.pg_utility_trigger_functions_readme();

rollback;
