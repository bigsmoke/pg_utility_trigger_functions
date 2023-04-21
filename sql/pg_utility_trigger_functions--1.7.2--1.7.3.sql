-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_utility_trigger_functions" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

comment on function coalesce_sibling_fields() is
$md$When a given column is `NULL`, this trigger function will coalesce it with one or more other given columns.

`coalesce_sibling_fields()` trigger function should be able to function in 3
different modes, depending on its argument given in the `CREATE TRIGGER`
definition:

  1. When multiple non-array arguments are given, the second argument and so
     forth will be the fallback values for the first value.
  2. When one or more array arguments are given, each of these array will be
     treated as the different function arguments as in the second mode.
  3. When a single `hstore` argument is supplied, each key in that `hstore` is
     treated as the preferred column and each value as the fallback value, as in
     `key = coalesce(key, value)`.

Currently, as of version 1.7.3, only the third of these three modes is implemented.
$md$;

--------------------------------------------------------------------------------------------------------------
