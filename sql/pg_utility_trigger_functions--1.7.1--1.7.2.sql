-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_utility_trigger_functions" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- `SET search_path`
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

--------------------------------------------------------------------------------------------------------------

-- `SET search_path`
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

--------------------------------------------------------------------------------------------------------------
