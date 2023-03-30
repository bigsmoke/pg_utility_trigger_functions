-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_utility_trigger_functions" to load this file. \quit

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
4. Argument 4 (optional): an array with the names of the columns that should be
   copied.  If the fourth argument is omitted, all the columns (except for the
   foreign key columns specified as argument 1 and 3) will be copied.  Remember:
   more often than not, explicit is better than implicit!

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
end;
$$;

--------------------------------------------------------------------------------------------------------------
