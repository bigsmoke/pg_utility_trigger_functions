-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_utility_trigger_functions" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

create or replace function copy_fields_from_foreign_table()
    returns trigger
    language plpgsql
    as $$
declare
    _foreign_key_column name;
    _foreign_table regclass;
    _foreign_target_column name;
    _foreign_fields name[];
    _foreign_field name;
    _foreign_record record;
    _fkey_is_null bool;
begin
    assert tg_level = 'ROW';
    assert tg_op in ('INSERT', 'UPDATE');
    assert tg_nargs between 3 and 4;

    _foreign_key_column := tg_argv[0];
    _foreign_table := tg_argv[1];
    _foreign_target_column := tg_argv[2];
    if tg_nargs > 3 then
        _foreign_fields := tg_argv[3]::name[];
    else
        _foreign_fields := (
            select
                local_att.attname
            from
                pg_catalog.pg_attribute as local_att
            where
                local_att.attrelid = tg_relid
                and exists(
                    select
                    from
                        pg_catalog.pg_attribute as foreign_att
                    where
                        foreign_att.attrelid = _foreign_table
                        and foreign_att.attname = local_att.attname
                        and foreign_att.attname != _foreign_target_column
                )
                and local_att.attname not in (_foreign_key_column)
        );
    end if;

    execute format('SELECT ($1).%I IS NULL', _foreign_key_column) using NEW into _fkey_is_null;
    if _fkey_is_null then
        return NEW;
    end if;

    execute 'SELECT ' || array_to_string(_foreign_fields, ', ')
        || ' FROM ' || _foreign_table
        || ' WHERE ' || quote_ident(_foreign_target_column) || ' = ($1).' || quote_ident(_foreign_key_column)
        using NEW
        into _foreign_record;

    foreach _foreign_field in array _foreign_fields
    loop
        NEW := NEW #= hstore(_foreign_record);
    end loop;

    return NEW;
end;
$$;

comment
    on function copy_fields_from_foreign_table()
    is $markdown$
The purpose of the `copy_fields_from_foreign_table()` trigger function is to
copy the given fields from the row in the given foreign table pointed at by the
given foreign key. It takes up to 4 arguments:

1. Argument 1 (required): the name of the foreign key column in the local
   table.
2. Argument 2 (required): the `regclass` (can be passed as `oid` or `name`) of
   the foreign relationship.
3. Argument 3 (required): the name of the identifying key column in the foreign
   table.
4. Argument 4 (optional): an array with the names of the columns that should be
   copied.  If the fourth argument is omitted, all the columns (except for the
   foreign key columns specified as argument 1 and 3) will be copied.  Remember:
   more often than not, explicit is better than implicit!

See the
[`test__copy_fields_from_foreign_table()`](#procedure-test__copy_fields_from_foreign_table)
routine for an example of this trigger function in action.

$markdown$;

create or replace procedure test__copy_fields_from_foreign_table()
    set search_path from current
    language plpgsql
    as $$
declare
    _b record;
begin
    create table test__a (
        a_id int
            primary key
        ,a_val_to_copy text
        ,a_val_to_not_copy text
    );
    create table test__b (
        a_id int
            not null
            references test__a(a_id)
        ,a_val_to_copy text
            not null
        ,a_val_to_not_copy text
        ,b_val text
    );
    create trigger copy_a_val_from_test__a
        before insert or update on test__b
        for each row
        execute function copy_fields_from_foreign_table(
            'a_id', 'test__a', 'a_id', '{a_val_to_copy}'
        );

    insert into test__a (a_id, a_val_to_copy, a_val_to_not_copy) values
        (1, 'Een', 'Eentje'),
        (2, 'Twee', 'Tweetje');

    insert into test__b (a_id, b_val)
        values (1, 'Uno')
        returning *
        into _b;

    assert _b.a_val_to_copy = 'Een';
    assert _b.a_val_to_not_copy is null;

    insert into test__b (a_id, a_val_to_not_copy, b_val)
        values (2, 'Dois', 'Twee')
        returning *
        into _b;

    assert _b.a_val_to_copy = 'Twee';
    assert _b.a_val_to_not_copy = 'Dois';

    raise transaction_rollback;  -- I could have use any error code, but this one seemed to fit best.
exception
    when transaction_rollback then
end;
$$;

comment
    on procedure test__copy_fields_from_foreign_table()
    is $markdown$
This is the test routine for the `copy_fields_from_foreign_table()` trigger
function.

The routine name is compliant with the `pg_tst` extension. An intentional
choice has been made to not _depend_ on the `pg_tst` extension its test runner
or developer-friendly assertions to keep the number of inter-extension
dependencies to a minimum.

$markdown$;

--------------------------------------------------------------------------------------------------------------

create or replace function fallback_to_fields_from_foreign_table()
    returns trigger
    language plpgsql
    as $$
declare
    _foreign_key_column name;
    _foreign_table regclass;
    _foreign_target_column name;
    _foreign_fields name[];
    _foreign_field name;
    _foreign_record record;
    _fkey_is_null bool;
begin
    assert tg_level = 'ROW';
    assert tg_op in ('INSERT', 'UPDATE');
    assert tg_nargs between 3 and 4;

    _foreign_key_column := tg_argv[0];
    _foreign_table := tg_argv[1];
    _foreign_target_column := tg_argv[2];
    if tg_nargs > 3 then
        _foreign_fields := tg_argv[3]::name[];
    else
        _foreign_fields := (
            select
                local_att.attname
            from
                pg_catalog.pg_attribute as local_att
            where
                local_att.attrelid = tg_relid
                and exists(
                    select
                    from
                        pg_catalog.pg_attribute as foreign_att
                     where
                        foreign_att.attrelid = _foreign_table
                        and foreign_att.attname = local_att.attname
                        and foreign_att.attname != _foreign_target_column
                )
                and local_att.attname not in (_foreign_key_column)
        );
    end if;

    execute format('SELECT ($1).%I IS NULL', _foreign_key_column) using NEW into _fkey_is_null;
    if _fkey_is_null then
        -- Yes, the FK column(s) can be NULL. If you don't like this, put a constraint on it.
        return NEW;
    end if;

    execute 'SELECT ' || (
            select
                string_agg(
                    'COALESCE(($1).' || quote_ident(ffield) || ', ftable.' || quote_ident(ffield) || ') AS '
                        || quote_ident(ffield),
                    ', '
                )
            from
                unnest(_foreign_fields) as ffield
        )
        || ' FROM ' || _foreign_table || ' AS ftable'
        || ' WHERE ' || quote_ident(_foreign_target_column) || ' = ($1).' || quote_ident(_foreign_key_column)
        using NEW
        into _foreign_record;

    NEW := NEW #= hstore(_foreign_record);

    return NEW;
end;
$$;

comment
    on function fallback_to_fields_from_foreign_table()
    is $markdown$
The purpose of the `fallback_to_fields_from_foreign_table()` trigger function
is to fallback to the given fields from the row in the given foreign table
pointed at by the given foreign key, if, and only if, these fields are `NULL`
in the local row.

`fallback_to_fields_from_foreign_table()` takes up to 4 arguments:

1. Argument 1 (required): the name of the foreign key column in the local
   table.
2. Argument 2 (required): the `regclass` (can be passed as `oid` or `name`) of
   the foreign relationship.
3. Argument 3 (required): the name of the identifying key column in the foreign
   table.
4. Argument 4 (optional): an array with the names of the columns that should be
   coalesced to.  If the fourth argument is omitted, all the columns (except
    for the foreign key columns specified as argument 1 and 3) will be copied.
    Remember: more often than not, explicit is better than implicit!

See the
[`test__fallback_to_fields_from_foreign_table()`](#routine-test__fallback_to_fields_from_foreign_table)
routine for an example of this trigger function in action.

$markdown$;

create or replace procedure test__fallback_to_fields_from_foreign_table()
    set search_path from current
    language plpgsql
    as $$
declare
    _b record;
begin
    create table test__a (
        a_id int
            primary key
        ,val_1 text
        ,val_2 text
        ,val_3 text
    );
    create table test__b (
        a_id int
            not null
            references test__a(a_id)
        ,val_1 text
        ,val_2 text
        ,val_3 text
    );
    create trigger fallback
        before insert or update on test__b
        for each row
        execute function fallback_to_fields_from_foreign_table(
            'a_id', 'test__a', 'a_id', '{val_1, val_2}'
        );

    insert into test__a (a_id, val_1, val_2, val_3) values
        (1, 'Een', 'Eentje', '1tje'),
        (2, 'Twee', 'Tweetje', '2tje');

    insert into test__b (a_id, val_1, val_2, val_3)
        values (1, 'Uno', null, 'a')
        returning *
        into _b;

    assert _b.val_1 = 'Uno';
    assert _b.val_2 = 'Eentje';
    assert _b.val_3 = 'a';

    insert into test__b (a_id, val_1, val_2, val_3)
        values (2, null, 'Doises', null)
        returning *
        into _b;

    assert _b.val_1 = 'Twee';
    assert _b.val_2 = 'Doises';
    assert _b.val_3 is null;

    raise transaction_rollback;  -- I could have use any error code, but this one seemed to fit best.
exception
    when transaction_rollback then
end;
$$;

comment
    on procedure test__fallback_to_fields_from_foreign_table()
    is $markdown$
This is the test routine for the `fallback_to_fields_from_foreign_table()` trigger
function.

The routine name is compliant with the `pg_tst` extension. An intentional
choice has been made to not _depend_ on the `pg_tst` extension its test runner
or developer-friendly assertions to keep the number of inter-extension
dependencies to a minimum.

$markdown$;

--------------------------------------------------------------------------------------------------------------

create or replace function pg_utility_trigger_functions_meta_pgxn()
    returns jsonb
    stable
    language sql
    return jsonb_build_object(
        'name'
        ,'pg_utility_trigger_functions'
        ,'abstract'
        ,'Some pet trigger functions that the extension author likes to follow him through various'
            ' PostgreSQL projects.'
        ,'description'
        ,'The pg_utility_trigger_functions PostgreSQL extensions bundles together some pet trigger functions'
            ' that the extension author likes to follow him through various PostgreSQL projects.'
        ,'version'
        ,(
            select
                pg_extension.extversion
            from
                pg_catalog.pg_extension
            where
                pg_extension.extname = 'pg_utility_trigger_functions'
        )
        ,'maintainer'
        ,array[
            'Rowan Rodrik van der Molen <rowan@bigsmoke.us>'
        ]
        ,'license'
        ,'gpl_3'
        ,'prereqs'
        ,'{
            "runtime": {
                "requires": {
                    "hstore": 0
                }
            },
            "test": {
                "requires": {
                    "pgtap": 0
                }
            }
        }'::jsonb
        ,'provides'
        ,('{
            "pg_utility_trigger_functions": {
                "file": "pg_utility_trigger_functions--1.0.0.sql",
                "version": "' || (
                    select
                        pg_extension.extversion
                    from
                        pg_catalog.pg_extension
                    where
                        pg_extension.extname = 'pg_utility_trigger_functions'
                ) || '",
                "docfile": "README.md"
            }
        }')::jsonb
        ,'resources'
        ,'{
            "homepage": "https://blog.bigsmoke.us/tag/pg_utility_trigger_functions",
            "bugtracker": {
                "web": "https://github.com/bigsmoke/pg_utility_trigger_functions/issues"
            },
            "repository": {
                "url": "https://github.com/bigsmoke/pg_utility_trigger_functions.git",
                "web": "https://github.com/bigsmoke/pg_utility_trigger_functions",
                "type": "git"
            }
        }'::jsonb
        ,'meta-spec'
        ,'{
            "version": "1.0.0",
            "url": "https://pgxn.org/spec/"
        }'::jsonb
        ,'generated_by'
        ,'`select pg_utility_trigger_functions_meta_pgxn()`'
        ,'tags'
        ,array[
            'plpgsql',
            'function',
            'functions',
            'trigger',
            'triggers',
            'utility'
        ]
    );

comment
    on function pg_utility_trigger_functions_meta_pgxn()
    is $markdown$
Returns the JSON meta data that has to go into the `META.json` file needed for
[PGXN—PostgreSQL Extension Network](https://pgxn.org/) packages.

The `Makefile` includes a recipe to allow the developer to: `make META.json` to
refresh the meta file with the function's current output, including the
`default_version`.

`pg_utility_trigger_functions` can indeed be found on PGXN:
https://pgxn.org/dist/pg_utility_trigger_functions/
$markdown$;

--------------------------------------------------------------------------------------------------------------

do $$
begin
    execute 'ALTER DATABASE ' || current_database()
        || ' SET pg_utility_trigger_functions.readme_url TO '
        || quote_literal('https://github.com/bigsmoke/pg_utility_trigger_functions/blob/master/README.md');
end;
$$;

--------------------------------------------------------------------------------------------------------------

alter function pg_utility_trigger_functions_readme()
    reset pg_readme.include_routine_definitions
    set pg_readme.include_routine_definitions_like to '{test__%}';

--------------------------------------------------------------------------------------------------------------
