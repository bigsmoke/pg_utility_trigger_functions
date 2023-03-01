-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_utility_trigger_functions" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

create function touch_referencing_table_columns()
    returns trigger
    language plpgsql
    as $$
declare
    _other_schema regnamespace;
    _other_table regclass;
    _referencing_column name;
    _referenced_column name;
    _touched_columns name;
begin
    assert tg_level = 'ROW';
    assert tg_op in ('INSERT', 'UPDATE', 'DELETE');
    assert tg_nargs = 3;

    _other_schema := tg_argv[0]::regnamespace;
    _other_table := tg_argv[1]::regclass;
    _other_columns := tg_argv[2:];

    execute 'UPDATE ' || quote_ident(_other_schema) || '.' || quote_ident(_other_table)
        || ' SET ' || quote_ident(_other_column) || ' = ' || quote_ident(_other_column);
        -- TODO: WHERE

    if tg_op in ('INSERT', 'UPDATE') then
        return NEW;
    elsif tg_op = 'DELETE' then
        return OLD;
    end if;
end;
$$;

comment on function touch_other_table_column() is $markdown$`touch_other_table_columns()` is your friend if you want an event in one table to trigger an event in another table.
$markdown$;



--------------------------------------------------------------------------------------------------------------
