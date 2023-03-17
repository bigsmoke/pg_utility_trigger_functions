-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_utility_trigger_functions" to load this file. \quit

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
    assert tg_nargs = 2;

    _extension_name_column := tg_argv[0];
    _extension_version_column := tg_argv[1];

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
            ,hint = 'Try adding a `WHEN (%I IS NOT NULL)` condition to the trigger.'
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
begin
    create table test__tbl(
        ext_name name
            not null
        ,ext_version text
            not null
    );

    create trigger set_installed_extension_version_from_name
        before insert on test__tbl
        for each row
        execute function set_installed_extension_version_from_name(
            'ext_name'
            ,'ext_version'
        );

    _expect := row(
        'pg_utility_trigger_functions'
        ,(select extversion from pg_extension where extname = 'pg_utility_trigger_functions')
    )::test__tbl;

    insert into test__tbl
        (ext_name)
    values
        (_expect.ext_name)
    returning
        *
    into
        _actual
    ;

    assert _actual = _expect,
        format('%s ≠ %s', _actual, _expect);

    raise assert_failure;
exception
    when assert_failure then
end;
$$;

--------------------------------------------------------------------------------------------------------------
