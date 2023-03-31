-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_utility_trigger_functions" to load this file. \quit

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

create or replace procedure test__overwrite_composite_field_in_referencing_table()
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
