#!/bin/bash

# Default values
VERBOSE=false
EXPORT=false
EXPORT_SCHEMA=false
IMPORT=false
TRANSFORM=false
LIST_SCHEMAS=false
ENV_FILE=""
HOST=""
DBNAME=""
PORT=""
USER=""
PASSWORD=""
FILE=""
SCHEMA=""
OLD_SCHEMA=""
NEWSCHEMA=""
PSQL_PATH="/opt/homebrew/opt/libpq/bin/psql"
PGDUMP_PATH="/opt/homebrew/opt/libpq/bin/pg_dump"

# Function to print the help message
function print_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --export                Export the database schema"
    echo "  -es, --export-schema SCHEMA Export a specific schema from the database"
    echo "  -i, --import                Import the database schema"
    echo "  -t, --transform             Transform the SQL file"
    echo "  -ls, --list-schemas         List all schemas in the database"
    echo "  -h, --host HOST             Database host"
    echo "  -d, --dbname DBNAME         Database name"
    echo "  -p, --port PORT             Database port"
    echo "  -u, --user USER             Database username"
    echo "  -w, --password PASSWORD     Database password"
    echo "  -f, --file FILE             SQL file"
    echo "  -o, --oldschema OLDSCHEMA   Old schema name for transformation"
    echo "  -n, --newschema NEWSCHEMA   New schema name for transformation"
    echo "      --psql-path PSQL_PATH   Path to the psql executable"
    echo "      --pgdump-path PGDUMP_PATH Path to the pg_dump executable"
    echo "      --env ENV_FILE          .env file with environment variables"
    echo "  -v, --verbose               Enable verbose mode"
    echo "  --help                      Show this help message and exit"
    echo ""
    echo "Environment Variables (if using --env flag):"
    echo "  PGHOST, PGDATABASE, PGPORT, PGUSER, PGPASSWORD, PGFILE, PGOLD_SCHEMA, PGNEWSCHEMA"
    echo ""
    echo "Examples:"
    echo "  Export the database schema:"
    echo "    ./pgclone.sh --export --host localhost --dbname mydb --port 5432 --user myuser --password mypassword --file mydb_dump.sql"
    echo "    ./pgclone.sh --export --env .env --file mydb_dump.sql"
    echo ""
    echo "  Export a specific schema from the database:"
    echo "    ./pgclone.sh --export-schema my_schema --host localhost --dbname mydb --port 5432 --user myuser --password mypassword --file mydb_dump.sql"
    echo "    ./pgclone.sh --export-schema my_schema --env .env --file mydb_dump.sql"
    echo ""
    echo "  List all schemas in the database:"
    echo "    ./pgclone.sh --list-schemas --host localhost --dbname mydb --port 5432 --user myuser --password mypassword"
    echo "    ./pgclone.sh --list-schemas --env .env"
    echo ""
    echo "  Transform the SQL file:"
    echo "    ./pgclone.sh --transform --file mydb_dump.sql --oldschema old_schema --newschema new_schema"
    echo "    ./pgclone.sh --transform --env .env --file mydb_dump.sql --oldschema old_schema --newschema new_schema"
    echo ""
    echo "  Import the database schema:"
    echo "    ./pgclone.sh --import --host localhost --dbname mydb --port 5432 --user myuser --password mypassword --file mydb_dump.sql"
    echo "    ./pgclone.sh --import --env .env --file mydb_dump.sql"
}

# Function to print verbose messages
function verbose() {
    if [ "$VERBOSE" = true ]; then
        echo "$@"
    fi
}

# Parse command line arguments
if [ "$#" -eq 0 ]; then
    print_help
    exit 0
fi

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -e|--export) EXPORT=true ;;
        -es|--export-schema) EXPORT_SCHEMA=true; SCHEMA="$2"; shift ;;
        -i|--import) IMPORT=true ;;
        -t|--transform) TRANSFORM=true ;;
        -ls|--list-schemas) LIST_SCHEMAS=true ;;
        -h|--host) HOST="$2"; shift ;;
        -d|--dbname) DBNAME="$2"; shift ;;
        -p|--port) PORT="$2"; shift ;;
        -u|--user) USER="$2"; shift ;;
        -w|--password) PASSWORD="$2"; shift ;;
        -f|--file) FILE="$2"; shift ;;
        -o|--oldschema) OLD_SCHEMA="$2"; shift ;;
        -n|--newschema) NEWSCHEMA="$2"; shift ;;
        --psql-path) PSQL_PATH="$2"; shift ;;
        --pgdump-path) PGDUMP_PATH="$2"; shift ;;
        --env) ENV_FILE="$2"; shift ;;
        -v|--verbose) VERBOSE=true ;;
        --help) print_help; exit 0 ;;
        *) echo "Unknown option: $1"; print_help; exit 1 ;;
    esac
    shift
done

# Load environment variables from file if specified
if [ -n "$ENV_FILE" ]; then
    if [ -f "$ENV_FILE" ]; then
        set -o allexport
        source "$ENV_FILE"
        set -o allexport -
    else
        echo "Error: Environment file '$ENV_FILE' not found."
        exit 1
    fi
fi

# Function to check required parameters
function check_required_parameters() {
    MISSING_PARAMS=()

    if [ -z "$HOST" ]; then HOST=$PGHOST; fi
    if [ -z "$DBNAME" ]; then DBNAME=$PGDATABASE; fi
    if [ -z "$PORT" ]; then PORT=$PGPORT; fi
    if [ -z "$USER" ]; then USER=$PGUSER; fi
    if [ -z "$PASSWORD" ]; then PASSWORD=$PGPASSWORD; fi

    if [ "$EXPORT" = true ] || [ "$EXPORT_SCHEMA" = true ] || [ "$IMPORT" = true ] || [ "$TRANSFORM" = true ]; then
        if [ -z "$FILE" ]; then FILE=$PGFILE; fi
        if [ -z "$FILE" ]; then MISSING_PARAMS+=("--file"); fi
    fi

    if [ -z "$HOST" ]; then MISSING_PARAMS+=("--host"); fi
    if [ -z "$DBNAME" ]; then MISSING_PARAMS+=("--dbname"); fi
    if [ -z "$PORT" ]; then MISSING_PARAMS+=("--port"); fi
    if [ -z "$USER" ]; then MISSING_PARAMS+=("--user"); fi
    if [ -z "$PASSWORD" ]; then MISSING_PARAMS+=("--password"); fi

    if [ ${#MISSING_PARAMS[@]} -ne 0 ]; then
        echo "Error: Missing required parameters: ${MISSING_PARAMS[*]}"
        echo "Run '$0 --help' for more information."
        exit 1
    fi
}

# Function to extract unique schema names from SQL file
function extract_schema_names() {
    local schema_names=$(awk '/^CREATE SCHEMA/ {print $3}' "$FILE" | tr -d ';' | sort -u)
    echo "$schema_names"
}

# Check for required parameters for export
if [ "$EXPORT" = true ]; then
    check_required_parameters
fi

# Check for required parameters for export schema
if [ "$EXPORT_SCHEMA" = true ]; then
    check_required_parameters
    if [ -z "$SCHEMA" ]; then
        echo "Error: Missing required parameter --export-schema SCHEMA"
        echo "Run '$0 --help' for more information."
        exit 1
    fi
fi

# Check for required parameters for import
if [ "$IMPORT" = true ]; then
    check_required_parameters
fi

# Check for required parameters for transform
if [ "$TRANSFORM" = true ]; then
    if [ -z "$FILE" ] || [ -z "$OLD_SCHEMA" ] || [ -z "$NEWSCHEMA" ]; then
        MISSING_PARAMS=()
        if [ -z "$FILE" ]; then MISSING_PARAMS+=("--file"); fi
        if [ -z "$OLD_SCHEMA" ]; then MISSING_PARAMS+=("--oldschema"); fi
        if [ -z "$NEWSCHEMA" ]; then MISSING_PARAMS+=("--newschema"); fi

        echo "Error: Missing required parameters for transform: ${MISSING_PARAMS[*]}"
        echo "Run '$0 --help' for more information."
        exit 1
    fi
fi

# Check for required parameters for list schemas
if [ "$LIST_SCHEMAS" = true ]; then
    if [ -z "$HOST" ]; then HOST=$PGHOST; fi
    if [ -z "$DBNAME" ]; then DBNAME=$PGDATABASE; fi
    if [ -z "$PORT" ]; then PORT=$PGPORT; fi
    if [ -z "$USER" ]; then USER=$PGUSER; fi
    if [ -z "$PASSWORD" ]; then PASSWORD=$PGPASSWORD; fi
    if [ -z "$HOST" ] || [ -z "$DBNAME" ] || [ -z "$PORT" ] || [ -z "$USER" ] || [ -z "$PASSWORD" ]; then
        MISSING_PARAMS=()
        if [ -z "$HOST" ]; then MISSING_PARAMS+=("--host"); fi
        if [ -z "$DBNAME" ]; then MISSING_PARAMS+=("--dbname"); fi
        if [ -z "$PORT" ]; then MISSING_PARAMS+=("--port"); fi
        if [ -z "$USER" ]; then MISSING_PARAMS+=("--user"); fi
        if [ -z "$PASSWORD" ]; then MISSING_PARAMS+=("--password"); fi

        echo "Error: Missing required parameters: ${MISSING_PARAMS[*]}"
        echo "Run '$0 --help' for more information."
        exit 1
    fi
fi

# Function to list schemas
function list_schemas() {
    verbose "Listing schemas..."
    PGPASSWORD="$PASSWORD" "$PSQL_PATH" --dbname="$DBNAME" --username="$USER" --host="$HOST" --port="$PORT" -c '\dn'
}

# Function to export the database schema
function export_schema() {
    verbose "Exporting schema..."
    PGPASSWORD="$PASSWORD" "$PGDUMP_PATH" --dbname="$DBNAME" --file="$FILE" --create -b --username="$USER" --host="$HOST" --port="$PORT"
    verbose "Schema export completed."
    
    # Extract schema names from SQL file and print them
    local schema_names=$(extract_schema_names)
    if [ -n "$schema_names" ]; then
        echo "Exported schemas to $FILE:"
        echo "$schema_names"
    else
        echo "Export completed, but could not determine schema names from $FILE"
    fi
}

# Function to export a specific schema
function export_specific_schema() {
    verbose "Exporting specific schema $SCHEMA..."
    PGPASSWORD="$PASSWORD" "$PGDUMP_PATH" --dbname="$DBNAME" --schema="$SCHEMA" --file="$FILE" --username="$USER" --host="$HOST" --port="$PORT"
    verbose "Schema $SCHEMA export completed."
}

# Function to import the database schema
function import_schema() {
    verbose "Importing schema..."
    PGPASSWORD="$PASSWORD" "$PSQL_PATH" --dbname="$DBNAME" --username="$USER" --host="$HOST" --port="$PORT" -f "$FILE"
    verbose "Schema import completed."
}

# Function to transform the SQL file
function transform_schema() {
    verbose "Transforming schema file..."
    # Remove any CREATE DATABASE, ALTER DATABASE, and CREATE SCHEMA commands
    sed -i '' '/CREATE DATABASE/d' "$FILE"
    sed -i '' '/ALTER DATABASE/d' "$FILE"
    sed -i '' '/CREATE SCHEMA/d' "$FILE"
    # Add CREATE SCHEMA and SET search_path commands at the beginning of the file
    sed -i '' "1i\\
    CREATE SCHEMA IF NOT EXISTS $NEWSCHEMA;\\
    SET search_path TO $NEWSCHEMA;
    " "$FILE"
    # Replace all occurrences of the old schema name with the new schema name
    sed -i '' "s/$OLD_SCHEMA/$NEWSCHEMA/g" "$FILE"
    verbose "Schema transformation completed."
}

# Execute the appropriate function based on the options
if [ "$EXPORT" = true ]; then
    export_schema
fi

if [ "$EXPORT_SCHEMA" = true ]; then
    export_specific_schema
fi

if [ "$IMPORT" = true ]; then
    import_schema
fi

if [ "$LIST_SCHEMAS" = true ]; then
    list_schemas
fi

if [ "$TRANSFORM" = true ]; then
    transform_schema
fi
