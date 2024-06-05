# pgclone
BASH wrapper for pg_dump and psql

## Features

Use case for `pgclone` is for easy copy and transformation of postgresql schemas

- List schemas
- dump database schema
- dump specific schema
- transform .sql file to update with new schema
- import new schema

## Command line options

Usage: ./pgclone.sh [OPTIONS]

Options:
  -e, --export                Export the database schema
  -es, --export-schema SCHEMA Export a specific schema from the database
  -i, --import                Import the database schema
  -t, --transform             Transform the SQL file
  -ls, --list-schemas         List all schemas in the database
  -h, --host HOST             Database host
  -d, --dbname DBNAME         Database name
  -p, --port PORT             Database port
  -u, --user USER             Database username
  -w, --password PASSWORD     Database password
  -f, --file FILE             SQL file
  -o, --oldschema OLDSCHEMA   Old schema name for transformation
  -n, --newschema NEWSCHEMA   New schema name for transformation
      --psql-path PSQL_PATH   Path to the psql executable
      --pgdump-path PGDUMP_PATH Path to the pg_dump executable
      --env ENV_FILE          .env file with environment variables
  -v, --verbose               Enable verbose mode
  --help                      Show this help message and exit

Environment Variables (if using --env flag):
  PGHOST, PGDATABASE, PGPORT, PGUSER, PGPASSWORD, PGFILE, PGOLD_SCHEMA, PGNEWSCHEMA

Examples:
  Export the database schema:
    ./pgclone.sh --export --host localhost --dbname mydb --port 5432 --user myuser --password mypassword --file mydb_dump.sql
    ./pgclone.sh --export --env .env --file mydb_dump.sql

  Export a specific schema from the database:
    ./pgclone.sh --export-schema my_schema --host localhost --dbname mydb --port 5432 --user myuser --password mypassword --file mydb_dump.sql
    ./pgclone.sh --export-schema my_schema --env .env --file mydb_dump.sql

  List all schemas in the database:
    ./pgclone.sh --list-schemas --host localhost --dbname mydb --port 5432 --user myuser --password mypassword
    ./pgclone.sh --list-schemas --env .env

  Transform the SQL file:
    ./pgclone.sh --transform --file mydb_dump.sql --oldschema old_schema --newschema new_schema
    ./pgclone.sh --transform --env .env --file mydb_dump.sql --oldschema old_schema --newschema new_schema

  Import the database schema:
    ./pgclone.sh --import --host localhost --dbname mydb --port 5432 --user myuser --password mypassword --file mydb_dump.sql
    ./pgclone.sh --import --env .env --file mydb_dump.sql
