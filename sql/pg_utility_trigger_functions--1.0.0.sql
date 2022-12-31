-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_utility_trigger_functions" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

comment
    on extension pg_utility_trigger_functions
    is $markdown$
The `pg_utility_trigger_functions` PostgreSQL extensions bundles together some
pet trigger functions that the extension
author—[BigSmoke](https://www.bigsmoke.us/)—likes to walk through various
PostgreSQL projects.

Feel free to copy-paste individual functions if you don't want to introduce an
extension dependency into your own extension/project.  Just try to respect the
GPL license that I released this under.

<?pg-readme-reference?>

<?pg-readme-colophon?>
$markdown$;

--------------------------------------------------------------------------------------------------------------

create or replace function pg_utility_trigger_functions_readme()
    returns text
    volatile
    set search_path from current
    set pg_readme.include_view_definitions to 'true'
    set pg_readme.include_routine_definitions to 'false'
    language plpgsql
    as $plpgsql$
declare
    _readme text;
begin
    create extension if not exists pg_readme;

    _readme := pg_extension_readme('pg_utility_trigger_functions'::name);

    raise transaction_rollback;  -- to drop extension if we happened to `CREATE EXTENSION` for just this.
exception
    when transaction_rollback then
        return _readme;
end;
$plpgsql$;

comment
    on function pg_utility_trigger_functions_readme()
    is $markdown$
Generates a `README.md` in Markdown format using the amazing power of the
`pg_readme` extension.  Temporarily installs `pg_readme` if it is not already
installed in the current database.

$markdown$;

--------------------------------------------------------------------------------------------------------------

create function update_updated_at()
    returns trigger
    set search_path from current
    as $$
begin
    assert tg_when = 'BEFORE';
    assert tg_level = 'ROW';
    assert tg_op in ('INSERT', 'UPDATE');

    NEW.updated_at := now();

    return NEW;
end;
$$ language plpgsql;

comment
    on function update_updated_at()
    is $markdown$
The `update_updated_at` trigger function sets the `updated_at` column of its
relation to `now()` whenever that relation is updated (or inserted into).

`update_updated_at()` uses `now()` without a schema qualifier rather than
`pg_catalog.now()`, to allow the mocking of now by manipulating the function's
`search_path`, for example to prepend the `mockable` schema from the
[`pg_mockable`](https://github.com/bigsmoke/pg_mockable) extension to it.

$markdown$;

--------------------------------------------------------------------------------------------------------------

create procedure test__update_updated_at()
    language plpgsql
    set plpgsql.check_asserts to true
    set search_path from current
    as $$
begin
    create table test__tbl (val int, updated_at timestamptz);
    create trigger update_updated_at before insert or update on test__tbl
        for each row execute function update_updated_at();

    insert into test__tbl(val) values (1), (2), (3);
    assert (select pg_catalog.count(*) from test__tbl where updated_at = pg_catalog.now()) = 3;

    -- The mocking could have easier been done with the `pg_mockable` extension instead, but let's be light
    -- on the inter-extension dependencies.
    create schema test__mock;
    create function test__mock.now()
        returns timestamptz
        language sql
        return pg_catalog.now() + interval '1 minute';
    assert test__mock.now() > pg_catalog.now();

    alter function update_updated_at()
        set search_path to test__mock, pg_catalog, pg_temp;

    update test__tbl set val = 10 + val where val = 1;
    assert (select pg_catalog.count(*) from test__tbl where updated_at > pg_catalog.now()) = 1,
        (select string_agg(distinct updated_at::text, ' ') from test__tbl);

    raise transaction_rollback;  -- I could have use any error code, but this one seemed to fit best.
exception
    when transaction_rollback then
end;
$$;

comment
    on procedure test__update_updated_at()
    is $markdown$
This routine tests the `update_updated_at()` trigger function.

The routine name is compliant with the `pg_tst` extension. An intentional
choice has been made to not _depend_ on the `pg_tst` extension its test runner
or developer-friendly assertions to keep the number of inter-extension
dependencies to a minimum.

$markdown$;

--------------------------------------------------------------------------------------------------------------

create function no_delete()
    returns trigger
    language plpgsql
as $$
begin
    assert tg_when = 'AFTER';
    assert tg_level = 'ROW';
    assert tg_op = 'DELETE';

    raise sqlstate 'P0DEL'
        using message = format('`DELETE FROM %I.%I` is forbidden.', tg_table_schema, tg_table_name);
end;
$$;

comment
    on function no_delete()
    is $markdown$
Attach the `no_delete()` trigger function to a relationship to disallow
`DELETE`s from that table when you want to go further than restricting `DELETE`
permissions via `GRANT`. Add a `WHEN` condition to the trigger if you want to
only block `DELETE`s in certain circumstances.

$markdown$;

--------------------------------------------------------------------------------------------------------------

create procedure test__no_delete()
    set plpgsql.check_asserts to true
    set search_path from current
    language plpgsql
    as $$
begin
    create table test__tbl (id int);
    create trigger no_delete after delete on test__tbl for each row execute function no_delete();

    insert into test__tbl (id) values (1), (2), (3);
    delete from test__tbl where id = 3;

    raise assert_failure
        using message = '`DELETE FROM test__tbl` should have been forbidden by trigger.';
exception
when sqlstate 'P0DEL' then
end;
$$;

comment
    on procedure test__no_delete()
    is $markdown$
This routine tests the `no_delete()` trigger function.

The routine name is compliant with the `pg_tst` extension. An intentional
choice has been made to not _depend_ on the `pg_tst` extension its test runner
or developer-friendly assertions to keep the number of inter-extension
dependencies to a minimum.

$markdown$;

--------------------------------------------------------------------------------------------------------------

create function nullify_columns()
    returns trigger
    language plpgsql
    set search_path from current
    as $$
declare
    _col_name name;
begin
    assert tg_name != 'nullify_columns',
        'Please be a bit more descriptive in your trigger name.';
    assert tg_when = 'BEFORE';
    assert tg_level = 'ROW';
    assert tg_op in ('INSERT', 'UPDATE');
    assert tg_nargs > 0;

    foreach _col_name in array tg_argv
    loop
        NEW := NEW #= hstore(_col_name, NULL);
    end loop;

    return NEW;
end;
$$;

comment
    on function nullify_columns()
    is $markdown$
The `nullify_columns()` trigger function is useful if you want to `nullify`
certain relationship columns in the case of certain trigger events (e.g.
`UPDATE`) or on certain `WHEN` conditions.

`nullify_columns()` takes on of more column names that will be nullified when
the trigger function is executed.

$markdown$;

--------------------------------------------------------------------------------------------------------------

create procedure test__nullify_columns()
    set plpgsql.check_asserts to true
    set search_path from current
    language plpgsql
    as $$
begin
    create table test__tbl (id int, a text, b timestamp default now());
    create trigger nullify_a_for_some_b
        before insert or update
        on test__tbl
        for each row
        when (NEW.a = 'b should be null')
        execute function nullify_columns('b');

    insert into test__tbl (id, a)
        values (1, 'b can be anything'), (2, 'b should be null'), (3, 'something');
    assert (select b from test__tbl where id = 1) is not null;
    assert (select b from test__tbl where id = 2) is null;
    assert (select b from test__tbl where id = 3) is not null;

    update test__tbl set a = 'b should be null' where id = 3;
    assert (select b from test__tbl where id = 1) is not null;
    assert (select b from test__tbl where id = 2) is null;
    assert (select b from test__tbl where id = 3) is null;

    raise transaction_rollback;  -- I could have use any error code, but this one seemed to fit best.
exception
    when transaction_rollback then
end;
$$;

comment
    on procedure test__nullify_columns()
    is $markdown$
This routine tests the `nullify_columns()` trigger function.

The routine name is compliant with the `pg_tst` extension. An intentional
choice has been made to not _depend_ on the `pg_tst` extension its test runner
or developer-friendly assertions to keep the number of inter-extension
dependencies to a minimum.

$markdown$;

--------------------------------------------------------------------------------------------------------------
