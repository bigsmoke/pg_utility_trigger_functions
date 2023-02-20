-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_utility_trigger_functions" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

create or replace function pg_utility_trigger_functions_meta_pgxn()
    returns jsonb
    stable
    language sql
    return jsonb_build_object(
        'name'
        ,'pg_utility_trigger_functions'
        ,'abstract'
        ,'Some pet trigger functions that the extension author likes to follow him through various'
            ' PostgreSQL projects.'
        ,'description'
        ,'The pg_utility_trigger_functions PostgreSQL extensions bundles together some pet trigger functions'
            ' that the extension author likes to follow him through various PostgreSQL projects.'
        ,'version'
        ,(
            select
                pg_extension.extversion
            from
                pg_catalog.pg_extension
            where
                pg_extension.extname = 'pg_utility_trigger_functions'
        )
        ,'maintainer'
        ,array[
            'Rowan Rodrik van der Molen <rowan@bigsmoke.us>'
        ]
        ,'license'
        ,'postgresql'
        ,'prereqs'
        ,'{
            "runtime": {
                "requires": {
                    "hstore": 0
                }
            },
            "test": {
                "requires": {
                    "pgtap": 0
                }
            }
        }'::jsonb
        ,'provides'
        ,('{
            "pg_utility_trigger_functions": {
                "file": "pg_utility_trigger_functions--1.0.0.sql",
                "version": "' || (
                    select
                        pg_extension.extversion
                    from
                        pg_catalog.pg_extension
                    where
                        pg_extension.extname = 'pg_utility_trigger_functions'
                ) || '",
                "docfile": "README.md"
            }
        }')::jsonb
        ,'resources'
        ,'{
            "homepage": "https://blog.bigsmoke.us/tag/pg_utility_trigger_functions",
            "bugtracker": {
                "web": "https://github.com/bigsmoke/pg_utility_trigger_functions/issues"
            },
            "repository": {
                "url": "https://github.com/bigsmoke/pg_utility_trigger_functions.git",
                "web": "https://github.com/bigsmoke/pg_utility_trigger_functions",
                "type": "git"
            }
        }'::jsonb
        ,'meta-spec'
        ,'{
            "version": "1.0.0",
            "url": "https://pgxn.org/spec/"
        }'::jsonb
        ,'generated_by'
        ,'`select pg_utility_trigger_functions_meta_pgxn()`'
        ,'tags'
        ,array[
            'plpgsql',
            'function',
            'functions',
            'trigger',
            'triggers',
            'utility'
        ]
    );

--------------------------------------------------------------------------------------------------------------
