
    drop role if exists last_insert_value;
    create role last_insert_value;

    create function util.remember_last_inserted_values_for_transaction_duration()
        returns trigger
        security definer
        language plpgsql
        as $$
declare
    -- TODO: Add underscores
    setting_name name;
    col_names name[];
    col_name name;
begin
    assert tg_when in ('BEFORE', 'AFTER');
    assert tg_level = 'ROW';
    assert tg_op = 'INSERT';

    if tg_nargs > 0 then
        col_names := tg_argv;
    else
        -- Fall back to primary key
        col_names := array(
            select
                a.attname
            from
                pg_catalog.pg_index as i
            join
                pg_catalog.pg_attribute as a
                on a.attrelid = i.indrelid
                and a.attnum = any(i.indkey)
            where
                i.indrelid = tg_table_name::regclass
                and i.indisprimary
        );
    end if;

    if tg_when = 'BEFORE' then
        if tg_name not like 'zzz_%' then
            raise warning 'BEFORE trigger name ON "%"."%" is "%"; better start the name with "zzz_"'
                ' so that it is run last.', tg_table_schema, tg_table_name, tg_name;
        end if;

        foreach col_name in array col_names loop
            if exists(
                select
                    *
                from
                    information_schema.columns
                where
                    columns.table_schema = tg_table_schema
                    and columns.table_name = tg_table_name
                    and columns.column_name = col_name
                    and columns.is_generated = 'ALWAYS'
            ) then
                raise exception '% is a generated column, which cannot be accessed from a BEFORE trigger.',
                    format('%I.%I.%I', tg_table_schema, tg_table_name, col_name);
            end if;
        end loop;
    end if;

    create temporary table if not exists last_insert_value (
        table_schema name
        ,table_name name
        ,column_name name
        ,column_value text
        ,primary key (table_schema, table_name, column_name)
    )
    on commit delete rows;

    foreach col_name in array col_names loop
        execute 'INSERT INTO last_insert_value (table_schema, table_name, column_name, column_value)'
                || ' VALUES ($1, $2, $3, $4.' || quote_ident(col_name) || ')'
                || ' ON CONFLICT (table_schema, table_name, column_name)'
                || ' DO UPDATE SET column_value = EXCLUDED.column_value'
            using tg_table_schema, tg_table_name, col_name, NEW;
    end loop;

    return NEW;
end;
    $$;
    alter function util.remember_last_inserted_values_for_transaction_duration
        owner to last_insert_value;

    create function util.last_insert_value(table_schema$ name, table_name$ name, column_name$ name)
    returns text
    language plpgsql
    security definer
    stable
    returns null on null input
    as $$
begin
    if not exists(
        select  *
        from    information_schema.tables
        where   table_name = 'last_insert_value'
                and table_type = 'LOCAL TEMPORARY'
    ) then
        return null;
    end if;

    return (
        select
            column_value
        from
            last_insert_value
        where
            table_schema = table_schema$
            and table_name = table_name$
            and column_name = column_name$
    );
end;
    $$;
    comment on function util.last_insert_value
        is 'This function does not allow SELECT … RETURNING to work, only SELECTs in subsequent statements.'
            ' For SELECT … RETURNING to work, it needs to be made VOLATILE, which will likely hinder'
            ' performance';
    alter function util.last_insert_value
        owner to last_insert_value;

    grant execute on function util.last_insert_value to public;

    create function util.forget_last_insert_value(table_schema$ name, table_name$ name, column_name$ name)
    returns void
    language plpgsql
    security definer
    volatile
    returns null on null input
    as $$
begin
    if not exists(
        select  *
        from    information_schema.tables
        where   table_name = 'last_insert_value'
                and table_type = 'LOCAL TEMPORARY'
    ) then
        return;
    end if;

    delete from
        last_insert_value
    where
        able_schema = table_schema$
        and table_name = table_name$
        and column_name = column_name$
    ;
end;
    $$;
    alter function util.forget_last_insert_value
        owner to last_insert_value;

    grant execute on function util.forget_last_insert_value to public;

    create procedure util.test__last_insert_values()
    language plpgsql
    as $$
declare
begin
    create table util.test_table (x int, y text, z int);
    create trigger remember_last_inserted_values_for_transaction_duration
        after insert on util.test_table
        for each row
        execute function util.remember_last_inserted_values_for_transaction_duration('x', 'y');

    insert into util.test_table (x, y, z)
    values (1, 'boom', 18), (2, 'roos', 19);

    perform tst.assert_equal(
        util.last_insert_value('util', 'test_table', 'x'), 2::text
    );
    perform tst.assert_equal(
        util.last_insert_value('util', 'test_table', 'y'), 'roos'
    );

    create table util.test_table2 (x int, y text, z int);
    create trigger zzz_remember_last_inserted_values_for_transaction_duration
        before insert on util.test_table2
        for each row
        execute function util.remember_last_inserted_values_for_transaction_duration('x', 'y');

    insert into util.test_table2 (x, y, z)
    values (1, 'boom', 18), (2, 'roos', 19);

    perform tst.assert_equal(
        util.last_insert_value('util', 'test_table2', 'x'), 2::text
    );
    perform tst.assert_equal(
        util.last_insert_value('util', 'test_table2', 'y'), 'roos'
    );

    raise transaction_rollback;  -- Such a fitting exception type.
exception
    when transaction_rollback then
        -- And we're rid of the test table + trigger.
end;
    $$;

