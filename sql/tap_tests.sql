begin;

create schema if not exists ext;

set search_path to ext;

create extension pg_utility_trigger_functions
    with schema ext cascade;

call test__update_updated_at();
call test__no_delete();
call test__nullify_columns();
call test__copy_fields_from_foreign_table();
call test__fallback_to_fields_from_foreign_table();
call test__set_installed_extension_version_from_name();
call test__coalesce_sibling_fields();

rollback;
