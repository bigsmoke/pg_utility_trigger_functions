-- Complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`.
\echo Use "CREATE EXTENSION pg_utility_trigger_functions" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- Crash when foreign record cannot be found.
create or replace function copy_fields_from_foreign_table()
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
    _found int;
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

    get diagnostics _found = ROW_COUNT;
    if _found = 0 then
        raise exception using
            message = 'Could not find foreign record to copy fields from.'
            ,hint = 'Ask the extension author to add support for `DEFERRABLE` FK constraints.'
        ;
    end if;

    NEW := NEW #= hstore(_foreign_record);

    return NEW;
end;
$$;

--------------------------------------------------------------------------------------------------------------

-- Be okay with missing foreign record.
create or replace function fallback_to_fields_from_foreign_table()
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
    _found int;
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
                    'Fourth argument to `fallback_to_fields_from_foreign_table()` must be either a `hstore`'
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
    get diagnostics _found = ROW_COUNT;

    -- We only update the local fields in case we found a foreign record, because in the case of a deferrable
    -- FK constraint, there might not be a foreign record yet when this trigger functions is run.
    if _found > 0 then
        NEW := NEW #= hstore(_foreign_record);
    end if;

    return NEW;
end;
$$;

--------------------------------------------------------------------------------------------------------------

-- Test ok-ness of missing foreign records.
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
        ,val_1 text
        ,val_2 text
        ,val_3 text
        ,constraint b_to_a foreign key (a_id) references test__a(a_id) deferrable initially deferred
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

        <<missing_fk_target>>
        begin
            set constraints b_to_a deferred;
            insert into test__b (a_id, val_1, val_2, val_3)
                values (3, 'Three', 'Tres', null)
                returning *
                into _b;

            assert _b.val_1 = 'Three' and _b.val_2 = 'Tres' and _b.val_3 is null;
        end missing_fk_target;
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

--------------------------------------------------------------------------------------------------------------
