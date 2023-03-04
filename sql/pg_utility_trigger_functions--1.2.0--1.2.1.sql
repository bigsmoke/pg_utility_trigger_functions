-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_utility_trigger_functions" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- Add <h1> heading.
-- Add PGXN icon.
-- Correct license claim.
comment
    on extension pg_utility_trigger_functions
    is $markdown$
# `pg_utility_trigger_functions`

[![PGXN version](https://badge.fury.io/pg/pg_utility_trigger_functions.svg)](https://badge.fury.io/pg/pg_utility_trigger_functions)

The `pg_utility_trigger_functions` PostgreSQL extensions bundles together some
pet trigger functions that the extension
author—[BigSmoke](https://www.bigsmoke.us/)—likes to walk through various
PostgreSQL projects.

Feel free to copy-paste individual functions if you don't want to introduce an
extension dependency into your own extension/project.  Just try to respect the
PostgreSQL license that this extension was released under.

<?pg-readme-reference?>

<?pg-readme-colophon?>
$markdown$;

--------------------------------------------------------------------------------------------------------------
