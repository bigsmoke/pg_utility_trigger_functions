begin;

create schema if not exists ext;

set search_path to ext;

create extension pg_utility_trigger_functions
    with schema ext cascade;

call test__update_updated_at();
call test__no_delete();
call test__nullify_columns();

rollback;
