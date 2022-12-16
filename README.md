---
pg_extension_name: pg_utility_trigger_functions
pg_extension_version: 1.0.0
pg_readme_generated_at: 2022-12-16 10:41:10.648996+00
pg_readme_version: 0.2.0
---

The `pg_utility_trigger_functions` PostgreSQL extensions bundles together some
pet trigger functions that the extension
author—[BigSmoke](https://www.bigsmoke.us/)—likes to walk through various
PostgreSQL projects.

Feel free to copy-paste individual functions if you don't want to introduce an
extension dependency into your own extension/project.  Just try to respect the
GPL license that I released this under.

## Object reference

### Routines

#### Function: `ext.no_delete()`

Attach the `no_delete()` trigger function to a relationship to disallow
`DELETE`s from that table when you want to go further than restricting `DELETE`
permissions via `GRANT`. Add a `WHEN` condition to the trigger if you want to
only block `DELETE`s in certain circumstances.

#### Function: `ext.nullify_columns()`

The `nullify_columns()` trigger function is useful if you want to `nullify`
certain relationship columns in the case of certain trigger events (e.g.
`UPDATE`) or on certain `WHEN` conditions.

`nullify_columns()` takes on of more column names that will be nullified when
the trigger function is executed.

#### Function: `ext.pg_utility_trigger_functions_readme()`

Generates a `README.md` in Markdown format using the amazing power of the
`pg_readme` extension.  Temporarily installs `pg_readme` if it is not already
installed in the current database.

#### Procedure: `ext.test__no_delete()`

This routine tests the `no_delete()` trigger function.

The routine name is compliant with the `pg_tst` extension. An intentional
choice has been made to not _depend_ on the `pg_tst` extension its test runner
or developer-friendly assertions to keep the number of inter-extension
dependencies to a minimum.

#### Procedure: `ext.test__nullify_columns()`

This routine tests the `nullify_columns()` trigger function.

The routine name is compliant with the `pg_tst` extension. An intentional
choice has been made to not _depend_ on the `pg_tst` extension its test runner
or developer-friendly assertions to keep the number of inter-extension
dependencies to a minimum.

#### Procedure: `ext.test__update_updated_at()`

This routine tests the `update_updated_at()` trigger function.

The routine name is compliant with the `pg_tst` extension. An intentional
choice has been made to not _depend_ on the `pg_tst` extension its test runner
or developer-friendly assertions to keep the number of inter-extension
dependencies to a minimum.

#### Function: `ext.update_updated_at()`

The `update_updated_at` trigger function sets the `updated_at` column of its
relation to `now()` whenever that relation is updated (or inserted into).

`update_updated_at()` uses `now()` without a schema qualifier rather than
`pg_catalog.now()`, to allow the mocking of now by manipulating the function's
`search_path`, for example to prepend the `mockable` schema from the
[`pg_mockable`](https://github.com/bigsmoke/pg_mockable) extension to it.

## Colophon

This `README.md` for the `pg_utility_trigger_functions` `extension` was automatically generated using the
[`pg_readme`](https://github.com/bigsmoke/pg_readme) PostgreSQL
extension.
