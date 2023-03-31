-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_utility_trigger_functions" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

comment on function overwrite_fields_in_referencing_table() is
$md$Copy specific (or all same-named) field values from this table to a table that references it.

`overwrite_fields_in_referencing_table()` takes 3 or 4 arguments:

1. Argument 1 (required): the identifying column referenced by the foreign key
   in the other table.
2. Argument 2 (required): the table that references the present table.
3. Argument 3 (required): the foreign key column in the other table.
4. Argument 4 (optional): the columns that should be copied.  This argument can
   be either:
   - omitted, so that all the columns (except for the foreign key columns
     specified as argument 1 and 3) will be copied (but remember that, more
     often than not, explicit is better than implicit);
   - an array with the same-named columns that should be copied; or
   - a `hstore` with the names of the ccolumns in the local table as keys and
     the names of the corresponding columns in the referencing table as values.

See the [`test__overwrite_fields_in_referencing_table()`](#procedure-test__overwrite_fields_in_referencing_table)
routine for examples of this trigger function in action.
$md$;

--------------------------------------------------------------------------------------------------------------
