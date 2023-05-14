---
pg_extension_name: pg_utility_trigger_functions
pg_extension_version: 1.8.0
pg_readme_generated_at: 2023-05-14 10:45:51.420959+01
pg_readme_version: 0.6.3
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

## Object reference

### Routines

#### Function: `coalesce_sibling_fields()`

When a given column is `NULL`, this trigger function will coalesce it with one or more other given columns.

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

Function return type: `trigger`

Function-local settings:

  *  `SET search_path TO ext, ext, pg_temp`

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

Function-local settings:

  *  `SET search_path TO ext, ext, pg_temp`

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

Function-local settings:

  *  `SET search_path TO ext, ext, pg_temp`

#### Function: `no_delete()`

Attach the `no_delete()` trigger function to a relationship to disallow `DELETE`s from that table when you want to go further than restricting `DELETE` permissions via `GRANT`.

Add a `WHEN` condition to the trigger if you want to only block `DELETE`s in
certain circumstances.

Function return type: `trigger`

#### Function: `nullify_columns()`

The `nullify_columns()` trigger function is useful if you want to `nullify` certain relationship columns in the case of certain trigger events (e.g.  `UPDATE`) or on certain `WHEN` conditions.

`nullify_columns()` takes on of more column names that will be nullified when
the trigger function is executed.

Function return type: `trigger`

Function-local settings:

  *  `SET search_path TO ext, ext, pg_temp`

#### Function: `overwrite_composite_field_in_referencing_table()`

Copy all the latest field values from this table to a composite field in another table that references it.

`overwrite_composite_field_in_referencing_table()` takes 3 arguments:

1. Argument 1 (required): the identifying column referenced by the same-named
   foreign key in the composite field in the other table.
2. Argument 2 (required): the table with the composite field that references the
   present table.
3. Argument 3 (required): the name of the composite field in the foreign table.
   That field must have all the same subfields

See the [`test__overwrite_composite_field_in_referencing_table()`](#procedure-test__overwrite_composite_field_in_referencing_table) routine for examples of this trigger function in action.

Function return type: `trigger`

Function-local settings:

  *  `SET search_path TO ext, ext, pg_temp`

#### Function: `overwrite_fields_in_referencing_table()`

Copy specific (or all same-named) field values from this table to a table that references it.

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

Function return type: `trigger`

Function-local settings:

  *  `SET search_path TO ext, ext, pg_temp`

#### Function: `pg_utility_trigger_functions_meta_pgxn()`

Returns the JSON meta data that has to go into the `META.json` file needed for PGXN—PostgreSQL Extension Network—packages.

The `Makefile` includes a recipe to allow the developer to: `make META.json` to
refresh the meta file with the function's current output, including the
`default_version`.

`pg_utility_trigger_functions` can indeed be found on PGXN:
https://pgxn.org/dist/pg_utility_trigger_functions/

Function return type: `jsonb`

Function attributes: `STABLE`

#### Function: `pg_utility_trigger_functions_readme()`

Generates a `README.md` in Markdown format using the amazing power of the `pg_readme` extension.  Temporarily installs `pg_readme` if it is not already installed in the current database.

Function return type: `text`

Function-local settings:

  *  `SET search_path TO ext, ext, pg_temp`
  *  `SET pg_readme.include_view_definitions TO true`
  *  `SET pg_readme.include_routine_definitions_like TO {test__%}`

#### Function: `set_installed_extension_version_from_name()`

Sets the installed extension version string in the column named in the second argument for the extension named in the second argument.

See the [`test__set_installed_extension_version_from_name()` test
procedure](#procedure-test__set_installed_extension_version_from_name) for a
working example of this trigger function.

Function return type: `trigger`

Function-local settings:

  *  `SET search_path TO ext, ext, pg_temp`

#### Procedure: `test__coalesce_sibling_fields()`

Procedure-local settings:

  *  `SET search_path TO ext, ext, pg_temp`
  *  `SET plpgsql.check_asserts TO true`
  *  `SET pg_readme.include_this_routine_definition TO true`

```sql
CREATE OR REPLACE PROCEDURE ext.test__coalesce_sibling_fields()
 LANGUAGE plpgsql
 SET search_path TO 'ext', 'ext', 'pg_temp'
 SET "plpgsql.check_asserts" TO 'true'
 SET "pg_readme.include_this_routine_definition" TO 'true'
AS $procedure$
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
$procedure$
```

#### Procedure: `test__copy_fields_from_foreign_table()`

This is the test routine for the `copy_fields_from_foreign_table()` trigger function.

The routine name is compliant with the `pg_tst` extension. An intentional
choice has been made to not _depend_ on the `pg_tst` extension its test runner
or developer-friendly assertions to keep the number of inter-extension
dependencies to a minimum.

Procedure-local settings:

  *  `SET search_path TO ext, ext, pg_temp`
  *  `SET plpgsql.check_asserts TO true`

```sql
CREATE OR REPLACE PROCEDURE ext.test__copy_fields_from_foreign_table()
 LANGUAGE plpgsql
 SET search_path TO 'ext', 'ext', 'pg_temp'
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

  *  `SET search_path TO ext, ext, pg_temp`
  *  `SET plpgsql.check_asserts TO true`

```sql
CREATE OR REPLACE PROCEDURE ext.test__fallback_to_fields_from_foreign_table()
 LANGUAGE plpgsql
 SET search_path TO 'ext', 'ext', 'pg_temp'
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
  *  `SET search_path TO ext, ext, pg_temp`

```sql
CREATE OR REPLACE PROCEDURE ext.test__no_delete()
 LANGUAGE plpgsql
 SET "plpgsql.check_asserts" TO 'true'
 SET search_path TO 'ext', 'ext', 'pg_temp'
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
  *  `SET search_path TO ext, ext, pg_temp`

```sql
CREATE OR REPLACE PROCEDURE ext.test__nullify_columns()
 LANGUAGE plpgsql
 SET "plpgsql.check_asserts" TO 'true'
 SET search_path TO 'ext', 'ext', 'pg_temp'
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

#### Procedure: `test__overwrite_composite_field_in_referencing_table()`

Procedure-local settings:

  *  `SET search_path TO ext, ext, pg_temp`
  *  `SET plpgsql.check_asserts TO true`
  *  `SET pg_readme.include_this_routine_definition TO true`

```sql
CREATE OR REPLACE PROCEDURE ext.test__overwrite_composite_field_in_referencing_table()
 LANGUAGE plpgsql
 SET search_path TO 'ext', 'ext', 'pg_temp'
 SET "plpgsql.check_asserts" TO 'true'
 SET "pg_readme.include_this_routine_definition" TO 'true'
AS $procedure$
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
$procedure$
```

#### Procedure: `test__overwrite_fields_in_referencing_table()`

Procedure-local settings:

  *  `SET search_path TO ext, ext, pg_temp`
  *  `SET plpgsql.check_asserts TO true`
  *  `SET pg_readme.include_this_routine_definition TO true`

```sql
CREATE OR REPLACE PROCEDURE ext.test__overwrite_fields_in_referencing_table()
 LANGUAGE plpgsql
 SET search_path TO 'ext', 'ext', 'pg_temp'
 SET "plpgsql.check_asserts" TO 'true'
 SET "pg_readme.include_this_routine_definition" TO 'true'
AS $procedure$
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
$procedure$
```

#### Procedure: `test__set_installed_extension_version_from_name()`

Procedure-local settings:

  *  `SET search_path TO ext, ext, pg_temp`
  *  `SET plpgsql.check_asserts TO true`
  *  `SET pg_readme.include_this_routine_definition TO true`

```sql
CREATE OR REPLACE PROCEDURE ext.test__set_installed_extension_version_from_name()
 LANGUAGE plpgsql
 SET search_path TO 'ext', 'ext', 'pg_temp'
 SET "plpgsql.check_asserts" TO 'true'
 SET "pg_readme.include_this_routine_definition" TO 'true'
AS $procedure$
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
  *  `SET search_path TO ext, ext, pg_temp`

```sql
CREATE OR REPLACE PROCEDURE ext.test__update_updated_at()
 LANGUAGE plpgsql
 SET "plpgsql.check_asserts" TO 'true'
 SET search_path TO 'ext', 'ext', 'pg_temp'
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

The `update_updated_at` trigger function sets the `updated_at` column of its relation to `now()` whenever that relation is updated (or inserted into).

`update_updated_at()` uses `now()` without a schema qualifier rather than
`pg_catalog.now()`, to allow the mocking of now by manipulating the function's
`search_path`, for example to prepend the `mockable` schema from the
[`pg_mockable`](https://github.com/bigsmoke/pg_mockable) extension to it.

Function return type: `trigger`

Function-local settings:

  *  `SET search_path TO ext, ext, pg_temp`

## Colophon

This `README.md` for the `pg_utility_trigger_functions` extension was automatically generated using the [`pg_readme`](https://github.com/bigsmoke/pg_readme) PostgreSQL extension.
