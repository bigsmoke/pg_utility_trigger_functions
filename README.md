---
pg_extension_name: pg_utility_trigger_functions
pg_extension_version: 1.3.1
pg_readme_generated_at: 2023-03-04 19:48:24.74596+00
pg_readme_version: 0.6.0
---

# `pg_utility_trigger_functions`

[![PGXN version](https://badge.fury.io/pg/pg_utility_trigger_functions.svg)](https://badge.fury.io/pg/pg_utility_trigger_functions)

The `pg_utility_trigger_functions` PostgreSQL extensions bundles together some
pet trigger functions that the extension
author—[BigSmoke](https://www.bigsmoke.us/)—likes to walk through various
PostgreSQL projects.

Feel free to copy-paste individual functions if you don't want to introduce an
extension dependency into your own extension/project.  Just try to respect the
PostgreSQL license that this extension was released under.

## Object reference

### Routines

#### Function: `copy_fields_from_foreign_table()`

The purpose of the `copy_fields_from_foreign_table()` trigger function is to copy the given fields from the row in the given foreign table pointed at by the given foreign key. It takes up to 4 arguments:

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

Function return type: `trigger`

#### Function: `fallback_to_fields_from_foreign_table()`

The purpose of the `fallback_to_fields_from_foreign_table()` trigger function is to fallback to the given fields from the row in the given foreign table pointed at by the given foreign key, if, and only if, these fields are `NULL` in the local row.

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

Function return type: `trigger`

#### Function: `no_delete()`

Attach the `no_delete()` trigger function to a relationship to disallow
`DELETE`s from that table when you want to go further than restricting `DELETE`
permissions via `GRANT`. Add a `WHEN` condition to the trigger if you want to
only block `DELETE`s in certain circumstances.

Function return type: `trigger`

#### Function: `nullify_columns()`

The `nullify_columns()` trigger function is useful if you want to `nullify`
certain relationship columns in the case of certain trigger events (e.g.
`UPDATE`) or on certain `WHEN` conditions.

`nullify_columns()` takes on of more column names that will be nullified when
the trigger function is executed.

Function return type: `trigger`

Function-local settings:

  *  `SET search_path TO ext, public, pg_temp`

#### Function: `pg_utility_trigger_functions_meta_pgxn()`

Returns the JSON meta data that has to go into the `META.json` file needed for
[PGXN—PostgreSQL Extension Network](https://pgxn.org/) packages.

The `Makefile` includes a recipe to allow the developer to: `make META.json` to
refresh the meta file with the function's current output, including the
`default_version`.

`pg_utility_trigger_functions` can indeed be found on PGXN:
https://pgxn.org/dist/pg_utility_trigger_functions/

Function return type: `jsonb`

Function attributes: `STABLE`

#### Function: `pg_utility_trigger_functions_readme()`

Generates a `README.md` in Markdown format using the amazing power of the
`pg_readme` extension.  Temporarily installs `pg_readme` if it is not already
installed in the current database.

Function return type: `text`

Function-local settings:

  *  `SET search_path TO ext, public, pg_temp`
  *  `SET pg_readme.include_view_definitions TO true`
  *  `SET pg_readme.include_routine_definitions_like TO {test__%}`

#### Procedure: `test__copy_fields_from_foreign_table()`

This is the test routine for the `copy_fields_from_foreign_table()` trigger function.

The routine name is compliant with the `pg_tst` extension. An intentional
choice has been made to not _depend_ on the `pg_tst` extension its test runner
or developer-friendly assertions to keep the number of inter-extension
dependencies to a minimum.

Procedure-local settings:

  *  `SET search_path TO ext, public, pg_temp`
  *  `SET plpgsql.check_asserts TO true`

```sql
CREATE OR REPLACE PROCEDURE ext.test__copy_fields_from_foreign_table()
 LANGUAGE plpgsql
 SET search_path TO 'ext', 'public', 'pg_temp'
 SET "plpgsql.check_asserts" TO 'true'
AS $procedure$
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
$procedure$
```

#### Procedure: `test__fallback_to_fields_from_foreign_table()`

This is the test routine for the `fallback_to_fields_from_foreign_table()` trigger function.

The routine name is compliant with the `pg_tst` extension. An intentional
choice has been made to not _depend_ on the `pg_tst` extension its test runner
or developer-friendly assertions to keep the number of inter-extension
dependencies to a minimum.

Procedure-local settings:

  *  `SET search_path TO ext, public, pg_temp`
  *  `SET plpgsql.check_asserts TO true`

```sql
CREATE OR REPLACE PROCEDURE ext.test__fallback_to_fields_from_foreign_table()
 LANGUAGE plpgsql
 SET search_path TO 'ext', 'public', 'pg_temp'
 SET "plpgsql.check_asserts" TO 'true'
AS $procedure$
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
$procedure$
```

#### Procedure: `test__no_delete()`

This routine tests the `no_delete()` trigger function.

The routine name is compliant with the `pg_tst` extension. An intentional
choice has been made to not _depend_ on the `pg_tst` extension its test runner
or developer-friendly assertions to keep the number of inter-extension
dependencies to a minimum.

Procedure-local settings:

  *  `SET plpgsql.check_asserts TO true`
  *  `SET search_path TO ext, public, pg_temp`

```sql
CREATE OR REPLACE PROCEDURE ext.test__no_delete()
 LANGUAGE plpgsql
 SET "plpgsql.check_asserts" TO 'true'
 SET search_path TO 'ext', 'public', 'pg_temp'
AS $procedure$
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
$procedure$
```

#### Procedure: `test__nullify_columns()`

This routine tests the `nullify_columns()` trigger function.

The routine name is compliant with the `pg_tst` extension. An intentional
choice has been made to not _depend_ on the `pg_tst` extension its test runner
or developer-friendly assertions to keep the number of inter-extension
dependencies to a minimum.

Procedure-local settings:

  *  `SET plpgsql.check_asserts TO true`
  *  `SET search_path TO ext, public, pg_temp`

```sql
CREATE OR REPLACE PROCEDURE ext.test__nullify_columns()
 LANGUAGE plpgsql
 SET "plpgsql.check_asserts" TO 'true'
 SET search_path TO 'ext', 'public', 'pg_temp'
AS $procedure$
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
$procedure$
```

#### Procedure: `test__update_updated_at()`

This routine tests the `update_updated_at()` trigger function.

The routine name is compliant with the `pg_tst` extension. An intentional
choice has been made to not _depend_ on the `pg_tst` extension its test runner
or developer-friendly assertions to keep the number of inter-extension
dependencies to a minimum.

Procedure-local settings:

  *  `SET plpgsql.check_asserts TO true`
  *  `SET search_path TO ext, public, pg_temp`

```sql
CREATE OR REPLACE PROCEDURE ext.test__update_updated_at()
 LANGUAGE plpgsql
 SET "plpgsql.check_asserts" TO 'true'
 SET search_path TO 'ext', 'public', 'pg_temp'
AS $procedure$
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
$procedure$
```

#### Function: `update_updated_at()`

The `update_updated_at` trigger function sets the `updated_at` column of its
relation to `now()` whenever that relation is updated (or inserted into).

`update_updated_at()` uses `now()` without a schema qualifier rather than
`pg_catalog.now()`, to allow the mocking of now by manipulating the function's
`search_path`, for example to prepend the `mockable` schema from the
[`pg_mockable`](https://github.com/bigsmoke/pg_mockable) extension to it.

Function return type: `trigger`

Function-local settings:

  *  `SET search_path TO ext, public, pg_temp`

## Colophon

This `README.md` for the `pg_utility_trigger_functions` extension was automatically generated using the [`pg_readme`](https://github.com/bigsmoke/pg_readme) PostgreSQL extension.
