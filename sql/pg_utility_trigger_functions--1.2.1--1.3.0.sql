-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_utility_trigger_functions" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- Add hstore() support.
-- Get rid of useless loop that did the same the exact same for number of column times.
-- Fix mode without 4th argument that automatically includes all same-named columns.
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
$md$;

create or replace procedure test__copy_fields_from_foreign_table()
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

-- Add hstore() support.
-- Get rid of useless loop that did the same the exact same for number of column times.
-- Fix mode without 4th argument that automatically includes all same-named columns.
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
$md$;

create or replace procedure test__fallback_to_fields_from_foreign_table()
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
