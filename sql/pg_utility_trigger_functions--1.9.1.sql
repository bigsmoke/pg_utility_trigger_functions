-- Complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`.
\echo Use "CREATE EXTENSION pg_utility_trigger_functions" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

comment on extension pg_utility_trigger_functions is
$markdown$
# `pg_utility_trigger_functions`

[![PGXN version](https://badge.fury.io/pg/pg_utility_trigger_functions.svg)](https://badge.fury.io/pg/pg_utility_trigger_functions)

The `pg_utility_trigger_functions` PostgreSQL extensions bundles together some
pet trigger functions that the extension
author—[BigSmoke](https://www.bigsmoke.us/)—likes to walk through various
PostgreSQL projects.

Feel free to copy-paste individual functions if you don't want to introduce an
extension dependency into your own extension/project.  Just try to respect the
PostgreSQL license that this extension was released under.

## Authors and contributors

* [Rowan](https://www.bigsmoke.us/) originated this extension in 2022 while
  developing the PostgreSQL backend for the [FlashMQ SaaS MQTT cloud
  broker](https://www.flashmq.com/).  Rowan does not like to see himself as a
  tech person or a tech writer, but, much to his chagrin, [he
  _is_](https://blog.bigsmoke.us/category/technology). Some of his chagrin
  about his disdain for the IT industry he poured into a book: [_Why
  Programming Still Sucks_](https://www.whyprogrammingstillsucks.com/).  Much
  more than a “tech bro”, he identifies as a garden gnome, fairy and ork rolled
  into one, and his passion is really to [regreen and reenchant his
  environment](https://sapienshabitat.com/).  One of his proudest achievements
  is to be the third generation ecological gardener to grow the wild garden
  around his beautiful [family holiday home in the forest of Norg, Drenthe,
  the Netherlands](https://www.schuilplaats-norg.nl/) (available for rent!).

<?pg-readme-reference?>

<?pg-readme-colophon?>
$markdown$;

--------------------------------------------------------------------------------------------------------------

create function pg_utility_trigger_functions_meta_pgxn()
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
        ,'postgresql'
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
                "file": "pg_utility_trigger_functions--1.9.1.sql",
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

comment on function pg_utility_trigger_functions_meta_pgxn() is
$md$Returns the JSON meta data that has to go into the `META.json` file needed for PGXN—PostgreSQL Extension Network—packages.

The `Makefile` includes a recipe to allow the developer to: `make META.json` to
refresh the meta file with the function's current output, including the
`default_version`.

`pg_utility_trigger_functions` can indeed be found on PGXN:
https://pgxn.org/dist/pg_utility_trigger_functions/
$md$;

--------------------------------------------------------------------------------------------------------------

do $$
begin
    if (select rolsuper from pg_catalog.pg_roles where rolname = current_user) then
        execute format(
            'ALTER DATABASE %I SET pg_utility_trigger_functions.readme_url TO %L'
            ,current_database()
            ,'https://github.com/bigsmoke/pg_utility_trigger_functions/blob/master/README.md'
        );
    end if;
end;
$$;

--------------------------------------------------------------------------------------------------------------

create function pg_utility_trigger_functions_readme()
    returns text
    volatile
    set search_path from current
    set pg_readme.include_view_definitions to 'true'
    set pg_readme.include_routine_definitions_like to '{test__%}'
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

comment on function pg_utility_trigger_functions_readme() is
$md$Generates a `README.md` in Markdown format using the amazing power of the `pg_readme` extension.  Temporarily installs `pg_readme` if it is not already installed in the current database.
$md$;

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

comment on function update_updated_at() is
$md$The `update_updated_at` trigger function sets the `updated_at` column of its relation to `now()` whenever that relation is updated (or inserted into).

`update_updated_at()` uses `now()` without a schema qualifier rather than
`pg_catalog.now()`, to allow the mocking of now by manipulating the function's
`search_path`, for example to prepend the `mockable` schema from the
[`pg_mockable`](https://github.com/bigsmoke/pg_mockable) extension to it.
$md$;

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

comment on procedure test__update_updated_at() is
$md$This routine tests the `update_updated_at()` trigger function.

The routine name is compliant with the `pg_tst` extension. An intentional
choice has been made to not _depend_ on the `pg_tst` extension its test runner
or developer-friendly assertions to keep the number of inter-extension
dependencies to a minimum.
$md$;

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

comment on function no_delete() is
$md$Attach the `no_delete()` trigger function to a relationship to disallow `DELETE`s from that table when you want to go further than restricting `DELETE` permissions via `GRANT`.

Add a `WHEN` condition to the trigger if you want to only block `DELETE`s in
certain circumstances.
$md$;

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

comment on procedure test__no_delete() is
$md$This routine tests the `no_delete()` trigger function.

The routine name is compliant with the `pg_tst` extension. An intentional
choice has been made to not _depend_ on the `pg_tst` extension its test runner
or developer-friendly assertions to keep the number of inter-extension
dependencies to a minimum.
$md$;

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

comment on function nullify_columns() is
$md$The `nullify_columns()` trigger function is useful if you want to `nullify` certain relationship columns in the case of certain trigger events (e.g.  `UPDATE`) or on certain `WHEN` conditions.

`nullify_columns()` takes on of more column names that will be nullified when
the trigger function is executed.
$md$;

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

comment on procedure test__nullify_columns() is
$md$This routine tests the `nullify_columns()` trigger function.

The routine name is compliant with the `pg_tst` extension. An intentional
choice has been made to not _depend_ on the `pg_tst` extension its test runner
or developer-friendly assertions to keep the number of inter-extension
dependencies to a minimum.
$md$;

--------------------------------------------------------------------------------------------------------------

create function coalesce_sibling_fields()
    returns trigger
    set search_path from current
    language plpgsql
    as $$
declare
    _select_expressions text;
    _field_values record;
begin
    assert tg_when = 'BEFORE';
    assert tg_op in ('INSERT', 'UPDATE');
    assert tg_level = 'ROW';
    assert tg_nargs >= 1;

    if tg_argv[0] ~ '=>' then
        assert tg_nargs = 1, 'Only a single `hstore` argument may be given.';
        _select_expressions := (
            select
                string_agg(
                    'coalesce(($1).' || quote_ident(e.key) || ', ($1).' || quote_ident(e.value)
                        || ') AS ' || quote_ident(e.key)
                    ,', '
                )
            from
                each(hstore(tg_argv[0])) as e(key, value)
        );
    elsif substr(tg_argv[0], 1, 1) = '{' then
        _select_expressions := (
            select
                string_agg(agg.coalesce_expression, ', ')
            from (
                select
                    'coalesce(($1).' || string_agg(quote_ident(d2.column_name), ', ($1).')
                        || ') AS ' || quote_ident(d1.arr[1]) as coalesce_expression
                from
                    unnest(tg_argv) with ordinality as arg(array_string, n)
                cross join lateral (
                    select
                        arg.array_string::text[] as arr
                    ) as d1
                cross join lateral
                    unnest(d1.arr) with ordinality as d2(column_name, n)
                group by
                    d1.arr
            ) as agg
        );
    else
        assert tg_nargs > 1;
        _select_expressions := (
            select
                'coalesce(($1).' || string_agg(quote_ident(arg.field_name), ', ($1).')
                    || ') AS ' || quote_ident(tg_argv[0])
            from
                unnest(tg_argv) as arg(field_name)
        );
    end if;

    execute 'SELECT ' || _select_expressions
        using NEW
        into _field_values;

    return NEW #= hstore(_field_values);
end;
$$;

comment on function coalesce_sibling_fields() is
$md$When a given column is `NULL`, this trigger function will coalesce it with one or more other given columns.

`coalesce_sibling_fields()` trigger function should be able to function in 3
different modes, depending on its argument given in the `CREATE TRIGGER`
definition:

  1. When multiple non-array arguments are given, the second argument and so
     forth will be the fallback values for the first value.
  2. When one or more array arguments are given, each of these array will be
     treated as the different function arguments as in the second mode.
  3. When a single `hstore` argument is supplied, each key in that `hstore` is
     treated as the preferred column and each value as the fallback value, as in
     `key = coalesce(key, value)`.

Currently, as of version 1.7.3, only the third of these three modes is implemented.
$md$;

--------------------------------------------------------------------------------------------------------------

create procedure test__coalesce_sibling_fields()
    set search_path from current
    set plpgsql.check_asserts to true
    set pg_readme.include_this_routine_definition to true
    language plpgsql
    as $$
declare
    _rec record;
begin
    create table test__tbl (a text, b text, c text, x text, y text, z text);
    create trigger coalesce_with_hstore_arg
        before insert on test__tbl
        for each row
        execute function coalesce_sibling_fields('a => b, x => y');

    insert into test__tbl
        (a, b, x, y)
    values
        (null, 'teenager', null, 'boot')
    returning
        *
    into
        _rec
    ;
    assert _rec.a = 'teenager';
    assert _rec.x = 'boot';

    insert into test__tbl
        (a, b, x, y)
    values
        ('adult', 'teenager', 'slipper', 'boot')
    returning
        *
    into
        _rec
    ;
    assert _rec.a = 'adult';
    assert _rec.x = 'slipper';

    drop trigger coalesce_with_hstore_arg
        on test__tbl;

    ---

    create trigger coalesce_with_multiple_args
        before insert on test__tbl
        for each row
        execute function coalesce_sibling_fields('a', 'b', 'c');

    insert into test__tbl
        (a, b, c)
    values
        (null, null, 'child')
    returning
        *
    into
        _rec
    ;
    assert _rec.a = 'child';

    insert into test__tbl
        (a, b, c)
    values
        ('adult', null, 'child')
    returning
        *
    into
        _rec
    ;
    assert _rec.a = 'adult';

    drop trigger coalesce_with_multiple_args
        on test__tbl;

    ---

    create trigger coalesce_with_array_args
        before insert on test__tbl
        for each row
        execute function coalesce_sibling_fields('{a, b, c}', '{x, y}');

    insert into test__tbl
        (a, b, c, x, y)
    values
        (null, null, 'child', null, 'boot')
    returning
        *
    into
        _rec
    ;
    assert _rec.a = 'child';
    assert _rec.x = 'boot';

    insert into test__tbl
        (a, b, c, x, y)
    values
        ('adult', null, 'child', 'slipper', 'boot')
    returning
        *
    into
        _rec
    ;
    assert _rec.a = 'adult';
    assert _rec.x = 'slipper';

    raise transaction_rollback;
exception
    when transaction_rollback then
end;
$$;

--------------------------------------------------------------------------------------------------------------

create function copy_fields_from_foreign_table()
    returns trigger
    set search_path from current
    language plpgsql
    as $$
declare
    _foreign_key_column name;
    _foreign_table regclass;
    _foreign_target_column name;
    _foreign_fields name[];
    _foreign_field name;
    _foreign_record record;
    _local_fields name[];
    _fkey_is_null bool;
begin
    assert tg_level = 'ROW';
    assert tg_op in ('INSERT', 'UPDATE');
    assert tg_nargs between 3 and 4;

    _foreign_key_column := tg_argv[0];
    _foreign_table := tg_argv[1];
    _foreign_target_column := tg_argv[2];
    if tg_nargs > 3 then
        if tg_argv[3] ~ '.+=>.+' then
            _local_fields := akeys(hstore(tg_argv[3]));
            _foreign_fields := avals(hstore(tg_argv[3]));
        elsif tg_argv[3] ~ '^{.*}$' then
            _local_fields := tg_argv[3]::name[];
            _foreign_fields := _local_fields;
        else
            raise exception using
                message = format(
                    'Fourth argument to `copy_fields_from_foreign_table()` must be either a `hstore`'
                    ' with local to foreign column name mappings, or a simple array, if the local and'
                    ' foreign column names are identical.  Instead, got: %s'
                    ,tg_argv[3]
                );
        end if;
    else
        _foreign_fields := (
            select
                array_agg(local_att.attname)
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
                        and foreign_att.attnum > 0
                )
                and local_att.attname != _foreign_key_column
        );
        _local_fields := _foreign_fields;
    end if;

    execute format('SELECT ($1).%I IS NULL', _foreign_key_column) using NEW into _fkey_is_null;
    if _fkey_is_null then
        return NEW;
    end if;

    execute 'SELECT ' || (
            select
                string_agg(
                    'ftable.' || quote_ident(ffield) || ' AS ' || quote_ident(lfield),
                    ', '
                )
            from
                unnest(_foreign_fields) with ordinality as f(ffield, idx)
            inner join
                unnest(_local_fields) with ordinality as l(lfield, idx)
                on l.idx = f.idx
        )
        || ' FROM ' || _foreign_table || ' AS ftable'
        || ' WHERE ' || quote_ident(_foreign_target_column) || ' = ($1).' || quote_ident(_foreign_key_column)
        using NEW
        into _foreign_record;

    NEW := NEW #= hstore(_foreign_record);

    return NEW;
end;
$$;

comment on function copy_fields_from_foreign_table() is
$md$The purpose of the `copy_fields_from_foreign_table()` trigger function is to copy the given fields from the row in the given foreign table pointed at by the given foreign key. It takes up to 4 arguments:

1. (required) the name of the foreign key column in the local table.
2. (required) the `regclass` (can be passed as `oid` or `name`) of the foreign
   relationship.
3. (required) the name of the identifying key column in the foreign
   table.
4. (optional) the columns that should be copied.  This argument can be either:
   - omitted, so that all the columns (except for the foreign key columns
     specified as argument 1 and 3) will be copied (but remember that, more
     often than not, explicit is better than implicit);
   - an array with the names of the columns that should be copied; or
   - a `hstore` with the names of the columns in the local table as keys and
     the names of the corresponding columns in the foreign table as values.

See the
[`test__copy_fields_from_foreign_table()`](#procedure-test__copy_fields_from_foreign_table)
routine for an example of this trigger function in action.
$md$;

--------------------------------------------------------------------------------------------------------------

create procedure test__copy_fields_from_foreign_table()
    set search_path from current
    set plpgsql.check_asserts to true
    language plpgsql
    as $$
declare
    _a1 record;
    _a2 record;
    _b record;
    _c record;
begin
    create table test__a (
        a_id int
            primary key
        ,val_1 text
        ,val_2 text
    );

    insert into test__a (a_id, val_1, val_2) values (1, 'Een', 'Eentje')
        returning * into _a1;
    insert into test__a (a_id, val_1, val_2) values (2, 'Twee', 'Tweetje')
        returning * into _a2;

    create table test__b (
        a_id int
            not null
            references test__a(a_id)
        ,val_1 text
            not null
        ,val_2 text
        ,b_val text
    );

    <<trigger_for_all_same_named_columns>>
    begin
        create trigger copy_fields_from_a
            before insert or update on test__b
            for each row
            execute function copy_fields_from_foreign_table(
                'a_id', 'test__a', 'a_id'  -- 4th trigger func. arg. omitted
            );
        insert into test__b (a_id, val_1, val_2, b_val)
            values (1, null, 'One', 'Uno')
            returning *
            into _b;

        assert _b.val_1 = _a1.val_1 and _b.val_2 = _a1.val_2,
            'NULL value should have coalesced into value from the identically-name foreign table column.';
        assert _b.val_2 = _a1.val_2,
            'Local NOT NULL value should have been ruthlessly overwritten.';
        assert _b.b_val = 'Uno',
            'Column that doesn''t exist in foreign table should have been ignored.';
    end trigger_for_all_same_named_columns;

    <<trigger_with_explicit_column_names>>
    begin
        create or replace trigger copy_fields_from_a
            before insert or update on test__b
            for each row
            execute function copy_fields_from_foreign_table(
                'a_id', 'test__a', 'a_id', '{val_1}'
            );

        insert into test__b (a_id, val_2)
            values (1, 'waarde')
            returning *
            into _b;

        assert _b.val_1 = _a1.val_1,
            'The specified column should have been overwritten with the foreign value.';
        assert _b.val_2 = 'waarde',
            'The non-specified column should be ignored by the trigger.';
    end trigger_with_explicit_column_names;

    <<trigger_with_hstore_column_mapping>>
    begin
        create table test__c (
            aaa_id int
                not null
                references test__a(a_id)
            ,val_one text
            ,val_two text
        );

        create trigger copy_fields_from_a
            before insert or update on test__c
            for each row
            execute function copy_fields_from_foreign_table(
                'aaa_id', 'test__a', 'a_id', 'val_one=>val_1, val_two=>val_2'
            );

        insert into test__c (aaa_id, val_one, val_two)
            values (1, 'Uno', null)
            returning *
            into _c;

        assert _c.val_one = _a1.val_1;
        assert _c.val_two = _a1.val_2;
    end;

    raise transaction_rollback;  -- I could have use any error code, but this one seemed to fit best.
exception
    when transaction_rollback then
end;
$$;

comment on procedure test__copy_fields_from_foreign_table() is
$md$This is the test routine for the `copy_fields_from_foreign_table()` trigger function.

The routine name is compliant with the `pg_tst` extension. An intentional
choice has been made to not _depend_ on the `pg_tst` extension its test runner
or developer-friendly assertions to keep the number of inter-extension
dependencies to a minimum.
$md$;

--------------------------------------------------------------------------------------------------------------

create function fallback_to_fields_from_foreign_table()
    returns trigger
    set search_path from current
    language plpgsql
    as $$
declare
    _foreign_key_column name;
    _foreign_table regclass;
    _foreign_target_column name;
    _foreign_fields name[];
    _foreign_field name;
    _foreign_record record;
    _local_fields name[];
    _fkey_is_null bool;
begin
    assert tg_level = 'ROW';
    assert tg_op in ('INSERT', 'UPDATE');
    assert tg_nargs between 3 and 4;

    _foreign_key_column := tg_argv[0];
    _foreign_table := tg_argv[1];
    _foreign_target_column := tg_argv[2];
    if tg_nargs > 3 then
        if tg_argv[3] ~ '.+=>.+' then
            _local_fields := akeys(hstore(tg_argv[3]));
            _foreign_fields := avals(hstore(tg_argv[3]));
        elsif tg_argv[3] ~ '^{.*}$' then
            _local_fields := tg_argv[3]::name[];
            _foreign_fields := _local_fields;
        else
            raise exception using
                message = format(
                    'Fourth argument to `copy_fields_from_foreign_table()` must be either a `hstore`'
                    ' with local to foreign column name mappings, or a simple array, if the local and'
                    ' foreign column names are identical.  Instead, got: %s'
                    ,tg_argv[3]
                );
        end if;
    else
        -- No fields specified; let's find all the same-named fields.
        _foreign_fields := (
            select
                array_agg(local_att.attname)
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
                        and foreign_att.attnum > 0
                )
                and local_att.attname not in (_foreign_key_column)
        );
        _local_fields := _foreign_fields;
    end if;

    execute format('SELECT ($1).%I IS NULL', _foreign_key_column) using NEW into _fkey_is_null;
    if _fkey_is_null then
        -- Yes, the FK column(s) can be NULL. If you don't like this, put a constraint on it.
        return NEW;
    end if;

    execute 'SELECT ' || (
            select
                string_agg(
                    'COALESCE(($1).' || quote_ident(lfield) || ', ftable.' || quote_ident(ffield) || ') AS '
                        || quote_ident(lfield),
                    ', '
                )
            from
                unnest(_foreign_fields) with ordinality as f(ffield, idx)
            inner join
                unnest(_local_fields) with ordinality as l(lfield, idx)
                on l.idx = f.idx
        )
        || ' FROM ' || _foreign_table || ' AS ftable'
        || ' WHERE ' || quote_ident(_foreign_target_column) || ' = ($1).' || quote_ident(_foreign_key_column)
        using NEW
        into _foreign_record;

    NEW := NEW #= hstore(_foreign_record);

    return NEW;
end;
$$;

comment on function fallback_to_fields_from_foreign_table() is
$md$The purpose of the `fallback_to_fields_from_foreign_table()` trigger function is to fallback to the given fields from the row in the given foreign table pointed at by the given foreign key, if, and only if, these fields are `NULL` in the local row.

`fallback_to_fields_from_foreign_table()` takes up to 4 arguments:

1. (required): the name of the foreign key column in the local table.
2. (required): the `regclass` (can be passed as `oid` or `name`) of the foreign
   relationship.
3. (required): the name of the identifying key column in the foreign
   table.
4. (optional) the columns that should be copied.  This argument can be either:
   - omitted, so that all the columns (except for the foreign key columns
     specified as argument 1 and 3) will be copied (but remember that, more
     often than not, explicit is better than implicit);
   - an array with the names of the columns that should be copied; or
   - a `hstore` with the names of the columns in the local table as keys and
     the names of the corresponding columns in the foreign table as values.

See the
[`test__fallback_to_fields_from_foreign_table()`](#routine-test__fallback_to_fields_from_foreign_table)
routine for an example of this trigger function in action.
$md$;

--------------------------------------------------------------------------------------------------------------

create procedure test__fallback_to_fields_from_foreign_table()
    set search_path from current
    set plpgsql.check_asserts to true
    language plpgsql
    as $$
declare
    _a1 record;
    _a2 record;
    _b record;
    _c record;
begin
    create table test__a (
        a_id int
            primary key
        ,val_1 text
        ,val_2 text
        ,val_3 text
    );

    insert into test__a (a_id, val_1, val_2, val_3) values (1, 'Een', 'Eentje', '1tje')
        returning * into _a1;
    insert into test__a (a_id, val_1, val_2, val_3) values (2, 'Twee', 'Tweetje', '2tje')
        returning * into _a2;

    create table test__b (
        a_id int
            not null
            references test__a(a_id)
        ,val_1 text
        ,val_2 text
        ,val_3 text
    );

    <<trigger_for_all_same_named_columns>>
    begin
        create trigger fallback
            before insert or update on test__b
            for each row
            execute function fallback_to_fields_from_foreign_table(
                'a_id', 'test__a', 'a_id'  -- 4th arg. omitted
            );

        insert into test__b (a_id, val_1, val_2, val_3)
            values (1, null, null, null)
            returning *
            into _b;

        assert _b.val_1 = _a1.val_1 and _b.val_2 = _a1.val_2 and _b.val_3 = _a1.val_3,
            'NULL values should have coalesced into values from the identically-name foreign table columns.';

        insert into test__b (a_id, val_1, val_2, val_3)
            values (1, 'One', 'Un', null)
            returning *
            into _b;

        assert _b.val_1 = 'One' and _b.val_2 = 'Un',
            'Local NOT NULL values should have been preserved.';
    end;

    <<trigger_with_explicit_column_names>>
    begin
        create or replace trigger fallback
            before insert or update on test__b
            for each row
            execute function fallback_to_fields_from_foreign_table(
                'a_id', 'test__a', 'a_id', '{val_1, val_2}'
            );
        insert into test__b (a_id, val_1, val_2, val_3)
            values (1, 'Uno', null, 'a')
            returning *
            into _b;

        assert _b.val_1 = 'Uno',
            'The local NOT NULL value should have been preserved.';
        assert _b.val_2 = 'Eentje',
            'The NULL value should have been coalesced into the foreign value.';
        assert _b.val_3 = 'a',
            'This value should _not_ have been copied from the foreign table.';

        insert into test__b (a_id, val_1, val_2, val_3)
            values (2, null, 'Doises', null)
            returning *
            into _b;

        assert _b.val_1 = 'Twee',
            'The NULL value should have coalesced into the foreign value.';
        assert _b.val_2 = 'Doises',
            'The local NOT NULL value should have been preserved.';
        assert _b.val_3 is null,
            'Nothing should have happened to the column left out of the trigger definition.';
    end trigger_with_explicit_column_names;

    <<trigger_with_hstore_column_mapping>>
    begin
        create table test__c (
            aaa_id int
                not null
                references test__a(a_id)
            ,val_one text
            ,val_two text
            ,val_three text
            ,val_3 text
        );
        create trigger fallback
            before insert or update on test__c
            for each row
            execute function fallback_to_fields_from_foreign_table(
                'aaa_id', 'test__a', 'a_id', 'val_one=>val_1, val_two=>val_2, val_3=>val_3'
            );

        insert into test__c (aaa_id, val_one, val_two, val_3)
            values (1, 'Uno', null, 'a')
            returning *
            into _c;

        assert _c.val_one = 'Uno';
        assert _c.val_two = _a1.val_2;
        assert _c.val_3 = 'a';

        insert into test__c (aaa_id, val_one, val_two, val_3)
            values (2, null, 'Doises', null)
            returning *
            into _c;

        assert _c.val_one = _a2.val_1;
        assert _c.val_two = 'Doises';
        assert _c.val_3 = _a2.val_3;
    end trigger_with_hstore_column_mapping;

    raise transaction_rollback;  -- I could have use any error code, but this one seemed to fit best.
exception
    when transaction_rollback then
end;
$$;

comment on procedure test__fallback_to_fields_from_foreign_table() is
$md$This is the test routine for the `fallback_to_fields_from_foreign_table()` trigger function.

The routine name is compliant with the `pg_tst` extension. An intentional
choice has been made to not _depend_ on the `pg_tst` extension its test runner
or developer-friendly assertions to keep the number of inter-extension
dependencies to a minimum.
$md$;

--------------------------------------------------------------------------------------------------------------

create function overwrite_fields_in_referencing_table()
    returns trigger
    set search_path from current
    language plpgsql
    as $$
declare
    _identifying_column name;
    _referencing_table regclass;
    _referencing_column name;
    _local_fields name[];
    _other_fields name[];
begin
    assert tg_when = 'AFTER';
    assert tg_op = 'UPDATE';
    assert tg_level = 'ROW';
    assert tg_nargs between 3 and 4;

    _identifying_column := tg_argv[0];
    _referencing_table := tg_argv[1];
    _referencing_column := tg_argv[2];
    if tg_nargs > 3 then
        if tg_argv[3] ~ '.+=>.+' then
            _local_fields := akeys(hstore(tg_argv[3]));
            _other_fields := avals(hstore(tg_argv[3]));
        elsif tg_argv[3] ~ '^{.*}$' then
            _local_fields := tg_argv[3]::name[];
            _other_fields := _local_fields;
        else
            raise exception using
                message = format(
                    'Fourth argument to `overwrite_fields_in_referencing_table()` must be either a `hstore`'
                    ' with local to foreign column name mappings, or a simple array, if the local and'
                    ' foreign column names are identical.  Instead, got: %s'
                    ,tg_argv[3]
                );
        end if;
    else
        _other_fields := (
            select
                array_agg(local_att.attname)
            from
                pg_catalog.pg_attribute as local_att
            where
                local_att.attrelid = tg_relid
                and exists(
                    select
                    from
                        pg_catalog.pg_attribute as foreign_att
                    where
                        foreign_att.attrelid = _referencing_table
                        and foreign_att.attname = local_att.attname
                        and foreign_att.attname != _referencing_column
                        and foreign_att.attnum > 0
                )
                and local_att.attname != _identifying_column
        );
        _local_fields := _other_fields;
    end if;

    execute 'UPDATE ' || _referencing_table || ' SET '
        || (
            select
                string_agg(
                    quote_ident(rfield) || ' = ($1).' || quote_ident(lfield),
                    ', '
                )
            from
                unnest(_other_fields) with ordinality as f(rfield, idx)
            inner join
                unnest(_local_fields) with ordinality as l(lfield, idx)
                on l.idx = f.idx
        )
        || ' WHERE ' || quote_ident(_referencing_column) || ' = ($1).' || quote_ident(_identifying_column)
        using NEW;

    return null;
end;
$$;

comment on function overwrite_fields_in_referencing_table() is
$md$Copy specific (or all same-named) field values from this table to a table that references it.

`overwrite_fields_in_referencing_table()` takes 3 or 4 arguments:

1. Argument 1 (required): the identifying column referenced by the foreign key
   in the other table.
2. Argument 2 (required): the table that references the present table.
3. Argument 3 (required): the foreign key column in the other table.
4. Argument 4 (optional): the columns that should be copied.  This argument can
   be either:
   - omitted, so that all the columns (except for the foreign key columns
     specified as argument 1 and 3) will be copied (but remember that, more
     often than not, explicit is better than implicit);
   - an array with the same-named columns that should be copied; or
   - a `hstore` with the names of the ccolumns in the local table as keys and
     the names of the corresponding columns in the referencing table as values.

See the [`test__overwrite_fields_in_referencing_table()`](#procedure-test__overwrite_fields_in_referencing_table)
routine for examples of this trigger function in action.
$md$;

--------------------------------------------------------------------------------------------------------------

create procedure test__overwrite_fields_in_referencing_table()
    set search_path from current
    set plpgsql.check_asserts to true
    set pg_readme.include_this_routine_definition to true
    language plpgsql
    as $$
declare
    _a1 record;
    _a2 record;
    _a3 record;
    _b1 record;
    _b2 record;
    _b3 record;
begin
    create table test__a (
        a_id int
            primary key
        ,val_1 text
        ,val_2 text
    );

    insert into test__a (a_id, val_1, val_2) values (1, 'Een', 'Eentje')
        returning * into _a1;
    insert into test__a (a_id, val_1, val_2) values (2, 'Twee', 'Tweetje')
        returning * into _a2;
    insert into test__a (a_id, val_1, val_2) values (3, 'Drie', 'Drietje')
        returning * into _a3;

    create table test__b (
        a_id int
            not null
            references test__a(a_id)
        ,val_1 text
            not null
        ,val_2 text
        ,b_val text
    );

    insert into test__b (a_id, val_1, val_2, b_val)
    select a.a_id, a.val_1, a.val_2, 'One' from test__a as a where a.a_id = _a1.a_id
    ;
    insert into test__b (a_id, val_1, val_2, b_val)
    select a.a_id, a.val_1, a.val_2, 'Two' from test__a as a where a.a_id = _a2.a_id
    ;
    insert into test__b (a_id, val_1, val_2, b_val)
    select a.a_id, a.val_1, a.val_2, 'Three' from test__a as a where a.a_id = _a3.a_id
    ;

    <<trigger_for_all_same_named_columns>>
    begin
        create trigger overwrite_fields_in_referencing_table
            after update on test__a
            for each row
            execute function overwrite_fields_in_referencing_table(
                'a_id', 'test__b', 'a_id'  -- 4th trigger func. arg. omitted
            );

        update
            test__a
        set
            val_1 = 'Uno'
            ,val_2 = 'Unoooo'
        where
            a_id = _a1.a_id
        returning
            *
        into
            _a1
        ;
        select b.* into _b1 from test__b as b where b.a_id = _a1.a_id;

        assert _a1.val_1 = _b1.val_1;
        assert _a1.val_2 = _b1.val_2;
    end trigger_for_all_same_named_columns;

    <<trigger_with_column_name_array>>
    begin
        create or replace trigger overwrite_fields_in_referencing_table
            after update on test__a
            for each row
            execute function overwrite_fields_in_referencing_table(
                'a_id', 'test__b', 'a_id', '{val_1}'
            );

        select b.* into _b2 from test__b as b where b.a_id = _a2.a_id;
        assert _a2.val_1 = _b2.val_1;
        assert _a2.val_2 = _b2.val_2;

        update
            test__a
        set
            val_1 = 'Deux'
            ,val_2 = 'Petit deux'
        where
            a_id = _a2.a_id
        returning
            *
        into
            _a2
        ;
        assert _a2.val_1 != _b2.val_1;
        assert _a2.val_2 != _b2.val_2;

        select b.* into _b2 from test__b as b where b.a_id = _a2.a_id;
        assert _a2.val_1 = _b2.val_1;
        assert _a2.val_2 != _b2.val_2;
    end trigger_with_column_name_array;

    <<trigger_with_hstore_column_mapping>>
    begin
        create or replace trigger overwrite_fields_in_referencing_table
            after update on test__a
            for each row
            execute function overwrite_fields_in_referencing_table(
                'a_id', 'test__b', 'a_id', 'val_1 => val_1'
            );

        select b.* into _b3 from test__b as b where b.a_id = _a3.a_id;
        assert _a3.val_1 = _b3.val_1;
        assert _a3.val_2 = _b3.val_2;

        update
            test__a
        set
            val_1 = 'Tres'
            ,val_2 = 'Petit tres'
        where
            a_id = _a3.a_id
        returning
            *
        into
            _a3
        ;
        assert _a3.val_1 != _b3.val_1;
        assert _a3.val_2 != _b3.val_2;

        select b.* into _b3 from test__b as b where b.a_id = _a3.a_id;
        assert _a3.val_1 = _b3.val_1;
        assert _a3.val_2 != _b3.val_2;
    end trigger_with_hstore_column_mapping;

    raise transaction_rollback;
exception
    when transaction_rollback then
end;
$$;

--------------------------------------------------------------------------------------------------------------

create function overwrite_composite_field_in_referencing_table()
    returns trigger
    set search_path from current
    language plpgsql
    as $$
declare
    _identifying_column name;
    _referencing_table regclass;
    _composite_column name;
begin
    assert tg_when = 'AFTER';
    assert tg_op = 'UPDATE';
    assert tg_level = 'ROW';
    assert tg_nargs = 3;

    _identifying_column := tg_argv[0];
    _referencing_table := tg_argv[1];
    _composite_column := tg_argv[2];

    execute 'UPDATE ' || _referencing_table || ' AS other SET '
        || quote_ident(_composite_column) || ' = row(($2).*)::' || tg_relid::regclass
        || ' WHERE (other.' || quote_ident(_composite_column) || ').' || quote_ident(_identifying_column)
        || ' = ($1).' || quote_ident(_identifying_column)
        using OLD, NEW;

    return null;
end;
$$;

comment on function overwrite_composite_field_in_referencing_table() is
$md$Copy all the latest field values from this table to a composite field in another table that references it.

`overwrite_composite_field_in_referencing_table()` takes 3 arguments:

1. Argument 1 (required): the identifying column referenced by the same-named
   foreign key in the composite field in the other table.
2. Argument 2 (required): the table with the composite field that references the
   present table.
3. Argument 3 (required): the name of the composite field in the foreign table.
   That field must have all the same subfields

See the [`test__overwrite_composite_field_in_referencing_table()`](#procedure-test__overwrite_composite_field_in_referencing_table) routine for examples of this trigger function in action.
$md$;

--------------------------------------------------------------------------------------------------------------

create procedure test__overwrite_composite_field_in_referencing_table()
    set search_path from current
    set plpgsql.check_asserts to true
    set pg_readme.include_this_routine_definition to true
    language plpgsql
    as $$
declare
    _a1 record;
    _b1 record;
begin
    create table test__a (
        a_id int
            primary key
        ,val_1 text
        ,val_2 text
    );

    insert into test__a (a_id, val_1, val_2) values (1, 'Een', 'Eentje')
        returning * into _a1;
    insert into test__a (a_id, val_1, val_2) values (2, 'Twee', 'Tweetje');
    insert into test__a (a_id, val_1, val_2) values (3, 'Drie', 'Drietje');

    create table test__b (
        c_id int
            primary key
        ,c_col text
        ,a test__a
            not null
    );

    insert into test__b
        (c_id, c_col, a)
    select
        1, 'Ein', row(a.*)::test__a
    from
        test__a as a
    where
        a.a_id = _a1.a_id
    returning
        (test__b.a).*
    into
        _b1
    ;
    assert _a1 = _b1;

    create or replace trigger overwrite_composite_field_in_referencing_table
        after update on test__a
        for each row
        execute function overwrite_composite_field_in_referencing_table('a_id', 'test__b', 'a');

    update
        test__a
    set
        val_1 = 'still 1'
        ,val_2 = 'still 2'
    where
        a_id = _a1.a_id
    returning
        *
    into
        _a1
    ;
    assert _a1 != _b1,
        'The `test__a` record should have been updated (and out of sync with the not yet reretrieved'
        || ' composite `test__b.a` field.';

    select (b.a).* into _b1 from test__b as b where c_id = 1;
    assert _a1 = _b1;

    raise transaction_rollback;
exception
    when transaction_rollback then
end;
$$;

--------------------------------------------------------------------------------------------------------------

create function set_installed_extension_version_from_name()
    returns trigger
    set search_path from current
    language plpgsql
    as $$
declare
    _extension_name_column name;
    _extension_version_column name;
    _extension_name name;
    _extension_version text;
begin
    assert tg_when = 'BEFORE';
    assert tg_op in ('INSERT', 'UPDATE');
    assert tg_level = 'ROW';
    assert tg_nargs in (0, 2);

    if tg_nargs = 2 then
        _extension_name_column := tg_argv[0];
        _extension_version_column := tg_argv[1];
    else
        _extension_name_column := 'pg_extension_name';
        _extension_version_column := 'pg_extension_version';
    end if;

    execute format('SELECT $1.%I, $1.%I', _extension_name_column, _extension_version_column)
        using NEW
        into _extension_name, _extension_version
    ;

    if _extension_name is null then
        raise null_value_not_allowed using
            message = format(
                'Unexpected %I.%I.%I IS NULL'
                ,tg_table_schema
                ,tg_table_name
                ,_extension_name_column
            )
            ,hint = format(
                'Try adding a `WHEN (NEW.%I IS NOT NULL)` condition to the trigger.'
                ,_extension_name_column
            )
            ,schema = tg_table_schema
            ,table = tg_table_name
            ,column = _extension_name_column
        ;
    end if;

    _extension_version := (select extversion from pg_catalog.pg_extension where extname = _extension_name);

    if _extension_version is null then
        raise no_data_found using
            message = format(
                'Could not find extension %s referenced in %I.%I.%I'
                ,_extension_name
                ,tg_table_schema
                ,tg_table_name
                ,_extension_name_column
            )
            ,schema = tg_table_schema
            ,table = tg_table_name
            ,column = _extension_name_column
        ;
    end if;

    NEW := NEW #= hstore(_extension_version_column::text, _extension_version);

    return NEW;
end;
$$;

comment on function set_installed_extension_version_from_name() is
$md$Sets the installed extension version string in the column named in the second argument for the extension named in the second argument.

See the [`test__set_installed_extension_version_from_name()` test
procedure](#procedure-test__set_installed_extension_version_from_name) for a
working example of this trigger function.
$md$;

--------------------------------------------------------------------------------------------------------------

create procedure test__set_installed_extension_version_from_name()
    set search_path from current
    set plpgsql.check_asserts to true
    set pg_readme.include_this_routine_definition to true
    language plpgsql
    as $$
declare
    _expect record;
    _actual record;
    _msg text;
    _hint text;
begin
    create table test__tbl(
        id serial primary key
        ,ext_name name
        ,ext_version text
    );


    <<missing_when_condition_in_trigger>>
    begin
        create trigger set_installed_extension_version_from_name
            before insert on test__tbl
            for each row
            execute function set_installed_extension_version_from_name(
                'ext_name'
                ,'ext_version'
            );

        insert into test__tbl default values;

        raise assert_failure using
            message = 'The trigger should have raised an exception about an unexpected NULL.';
    exception
        when null_value_not_allowed then
            get stacked diagnostics
                _msg := message_text
                ,_hint := pg_exception_hint
            ;
            assert _msg = format('Unexpected %I.test__tbl.ext_name IS NULL', current_schema);
            assert _hint = 'Try adding a `WHEN (NEW.ext_name IS NOT NULL)` condition to the trigger.';
    end missing_when_condition_in_trigger;

    <<with_explicit_column_names>>
    begin
        create trigger set_installed_extension_version_from_name
            before insert on test__tbl
            for each row
            when (NEW.ext_name is not null)
            execute function set_installed_extension_version_from_name(
                'ext_name'
                ,'ext_version'
            );

        _expect := row(2, null, null)::test__tbl;
        insert into test__tbl default values returning * into _actual;
        assert _actual = _expect, format('%s ≠ %s', _actual, _expect);

        _expect := row(
            3
            ,'pg_utility_trigger_functions'
            ,(select extversion from pg_extension where extname = 'pg_utility_trigger_functions')
        )::test__tbl;
        insert into test__tbl (ext_name) values (_expect.ext_name) returning * into _actual;
        assert _actual = _expect, format('%s ≠ %s', _actual, _expect);

        <<not_installed_extension_name>>
        begin
            insert into test__tbl (ext_name) values ('invalid_extension_name');

            raise assert_failure using
                message = 'The trigger should have raised an exception about unrecognized extension.';
        exception
            when no_data_found then
                get stacked diagnostics _msg := message_text;
                assert _msg = format(
                    'Could not find extension invalid_extension_name referenced in %I.test__tbl.ext_name'
                    ,current_schema
                );
        end not_installed_extension_name;
    end with_explicit_column_names;

    <<with_default_column_names>>
    begin
        create table test__tbl2 (
            id serial primary key
            ,pg_extension_name name
            ,pg_extension_version text
        );

        create trigger set_installed_extension_version_from_name
            before insert on test__tbl2
            for each row
            when (NEW.pg_extension_name is not null)
            execute function set_installed_extension_version_from_name();

        _expect := row(
            1
            ,'pg_utility_trigger_functions'
            ,(select extversion from pg_extension where extname = 'pg_utility_trigger_functions')
        )::test__tbl2;

        insert into test__tbl2
            (pg_extension_name)
        values
            (_expect.pg_extension_name)
        returning *
        into _actual
        ;

        assert _actual = _expect, format('%s ≠ %s', _actual, _expect);
    end with_default_column_names;

    raise transaction_rollback;
exception
    when transaction_rollback then
end;
$$;

--------------------------------------------------------------------------------------------------------------

create function debug_row()
    returns trigger
    language plpgsql
    as $$
begin
    raise notice 'TRIGGER % % % ON %.%: jsonb_pretty(to_jsonb(OLD.*) = %; jsonb_pretty(to_jsonb(NEW.*)) = %'
        ,quote_ident(tg_name), tg_when, tg_op, quote_ident(tg_table_schema), quote_ident(tg_table_name)
        ,jsonb_pretty(to_jsonb(OLD.*)), jsonb_pretty(to_jsonb(NEW.*));

    if tg_when = 'BEFORE' and tg_op in ('INSERT', 'UPDATE') then
        return NEW;
    end if;

    if tg_when = 'BEFORE' and tg_op = 'DELETE' then
        return OLD;
    end if;

    return null;
end;
$$;

comment on function debug_row() is
$md$A simple trigger function to help you output the OLD and NEW row BEFORE or AFTER any operation on a ROW.
$md$;

--------------------------------------------------------------------------------------------------------------
