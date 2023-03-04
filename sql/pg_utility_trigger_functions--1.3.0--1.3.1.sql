-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_utility_trigger_functions" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- Cleaner formatting of list.
-- Bring documentation of the 4th argument in line with the added `hstore` support.
comment on function copy_fields_from_foreign_table() is
$md$The purpose of the `copy_fields_from_foreign_table()` trigger function is to copy the given fields from the row in the given foreign table pointed at by the given foreign key. It takes up to 4 arguments:

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
$md$;

--------------------------------------------------------------------------------------------------------------

-- Cleaner formatting of list.
-- Bring documentation of the 4th argument in line with the added `hstore` support.
comment on function fallback_to_fields_from_foreign_table() is
$md$The purpose of the `fallback_to_fields_from_foreign_table()` trigger function is to fallback to the given fields from the row in the given foreign table pointed at by the given foreign key, if, and only if, these fields are `NULL` in the local row.

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
$md$;

--------------------------------------------------------------------------------------------------------------
