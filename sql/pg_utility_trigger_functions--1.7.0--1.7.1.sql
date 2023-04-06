-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_utility_trigger_functions" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- Add support for default column names in case no arguments are given.
create or replace function set_installed_extension_version_from_name()
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

--------------------------------------------------------------------------------------------------------------

create or replace procedure test__set_installed_extension_version_from_name()
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
