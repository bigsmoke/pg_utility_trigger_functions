
-- Maybe it would be better to simply enforce an extension name and then forbid NULL? Yes.
create function restrict_operation_to_create_and_alter_extension()
    returns trigger
    set search_path from current
    language plpgsql
    as $$
declare
    _extension_whitelist name[] := null;
begin
    assert tg_when = 'AFTER';
    assert tg_level = 'STATEMENT';
    assert tg_nargs < 2;

    if tg_nargs = 1 then
        _extension_whitelist := tg_argv[0]::name[];
    end if;

    -- CREATE TEMPORARY TABLE to check if we are in an extension context

    return null;
end;
$$;

create function detect_and_track_extension_context

--------------------------------------------------------------------------------------------------------------
