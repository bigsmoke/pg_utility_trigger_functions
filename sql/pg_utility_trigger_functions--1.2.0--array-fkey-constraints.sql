-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_utility_trigger_functions" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

create function array_fkeys_dependent_constraint()
    returns trigger
    set search_path from current
    language plpgsql
    as $$
declare
    _fkeys_array_col name;
    _referenced_schema name;
    _referenced_table name;
    _referenced_column name;
    _on_delete text;
    _on_update text;
    _fkey_value record;
begin
    assert tg_when = 'AFTER';
    assert tg_level = 'ROW';
    assert tg_op in ('INSERT', 'UPDATE');
    assert tg_nargs = 6;

    _fkeys_array_col := tg_argv[0];
    _referenced_schema := tg_argv[1];
    _referenced_table := tg_argv[2];
    _referenced_column := tg_argv[3];
    _on_delete := regexp_match(tg_argv[4], '^ON DELETE (.*)$')[1];
    _on_update := regexp_match(tg_argv[5], '^ON UPDATE (.*)$')[1];

    for _fkey_value in execute format(
        $sql$
            SELECT
                v.array_index
                v.array_value
            FROM
                unnest(($1).%1$I) WITH ORDINALITY AS v(array_value, array_index)
            WHERE NOT EXISTS (
                SELECT FROM %2$I.%3$I WHERE %3$I.%4$I = v.val
            )
        $sql$
        ,_fkeys_array_col
        ,_referenced_schema
        ,_referenced_table
        ,_referenced_column
    ) using NEW loop
        raise foreign_key_violation using
            message = format(
                '%I.%I.%I[%s] = %s violated the foreign key constraint trigger %I.'
                ,tg_table_schema
                ,tg_table_name
                ,_fkeys_array_col
                ,_fkey_val.array_index
                ,_fkey_val.array_value
                ,tg_name
            )
            ,details = format(
                '%I.%I.%I = %s doesn''t exist.'
                ,_referenced_schema
                ,_referenced_table
                ,_referenced_column
                ,_fkey_val.array_value
            );
    end loop;

    return NEW;
end;
$$;

comment on function array_fkeys_dependent_constraint() is
$md$Use this trigger function to set up a foreign key constraint for all the values in an array attribute.

Natively, Postgres doesn't support foreign key constraints on array values.
Once it does, of course, that native functionality will be preferred over this
then-to-be-deprecated function.

See the the
[`test__array_fkeys_constraint()`](#procedure-test__array_fkeys_constraint)
routine for an example of how to use this trigger function.
$md$;

--------------------------------------------------------------------------------------------------------------

create function array_fkeys_dependency_constraint()
    returns trigger
    set search_path from current
    language plpgsql
    as $$
declare
    _fkeys_array_col name;
    _referencing_schema name;
    _referencing_table name;
    _referencing_column name;
    _on_delete text;
    _on_update text;
    _fkey_value record;
begin
    assert tg_when = 'AFTER';
    assert tg_level = 'ROW';
    assert tg_op in ('INSERT', 'UPDATE');
    assert tg_nargs = 6;
$$;

comment on function array_fkeys_dependency_constraint() is
$md$This trigger function is to be used to enforce referential integrity from the end that the foreign key is pointing _to_.

It is the counterpart of the
[`array_fkeys_dependent_constraint()`](#function-array_fkeys_dependent_constraint)
function.
$md$;

--------------------------------------------------------------------------------------------------------------

create procedure test__array_fkeys_constraint()
    set plpgsql.check_asserts to true
    set search_path to current
    set pg_readme.include_this_routine_definition to true
    language plpgsql
    as $$
begin
    create table color_tbl (
        color_name text
            primary key
        ,color_html_hex text
            not null
    );

    create table person_tbl (
        person_name text
            primary key
        ,favorite_color_names text[]
            not null
    );

    create constraint trigger favorite_color_names_fkey
        after insert or update to

    raise transaction_rollback;
exception
    when transaction_rollback then
end;
$$;

--------------------------------------------------------------------------------------------------------------
