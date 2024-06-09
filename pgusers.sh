#!/bin/bash

# Function to print usage
usage() {
  echo "Usage: $0 --env <path_to_env_file> --project <project_name>"
  exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -ne 4 ]; then
  usage
fi

# Parse arguments
while [ "$#" -gt 0 ]; do
  case "$1" in
    --env)
      ENV_FILE="$2"
      shift 2
      ;;
    --project)
      PROJECT_NAME="$2"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

# Check if the env file exists
if [ ! -f "$ENV_FILE" ]; then
  echo "Error: Environment file '$ENV_FILE' not found!"
  exit 1
fi

# Source the environment variables from the file
set -a
source "$ENV_FILE"
set +a

# Validate that the schema name is set
if [ -z "$PGSCHEMA" ]; then
  echo "Error: PGSCHEMA is not set in the environment file."
  exit 1
fi

# Get today's date in YYYYMMDD format
TODAY=$(date +%Y%m%d)

# Directory for reports
SCRIPT_DIR=$(dirname "$0")
REPORTS_DIR="$SCRIPT_DIR/reports"

# Create reports directory if it doesn't exist
mkdir -p "$REPORTS_DIR"

# Output files
USERS_FILE="$REPORTS_DIR/${PROJECT_NAME}_users_and_roles_${TODAY}.txt"
TABLE_PRIVILEGES_FILE="$REPORTS_DIR/${PROJECT_NAME}_table_privileges_${TODAY}.txt"
SCHEMA_PRIVILEGES_FILE="$REPORTS_DIR/${PROJECT_NAME}_schema_privileges_${TODAY}.txt"
ROLE_MEMBERSHIPS_FILE="$REPORTS_DIR/${PROJECT_NAME}_role_memberships_${TODAY}.txt"
DATABASE_PRIVILEGES_FILE="$REPORTS_DIR/${PROJECT_NAME}_database_privileges_${TODAY}.txt"
MIGRATION_PRIVILEGES_FILE="$REPORTS_DIR/${PROJECT_NAME}_migration_privileges_${TODAY}.txt"
HTML_REPORT_FILE="$REPORTS_DIR/${PROJECT_NAME}_report_${TODAY}.html"

# PSQL command with connection details
PSQL_CMD="$PSQL_PATH -h $PGHOST -p $PGPORT -d $PGDATABASE -U $PGUSER"

# Function to run a query and save the output to a file
run_query() {
  local query=$1
  local output_file=$2
  echo "Running query and saving to $output_file..."
  PGPASSWORD=$PGPASSWORD $PSQL_CMD -c "$query" | sed 's/| t |/| True |/g; s/| f |/| False |/g' > $output_file
}

# Function to convert text file to HTML table
convert_to_html_table() {
  local input_file=$1
  local title=$2
  local section_id=$3
  echo "<h2 id=\"$section_id\">$title <a href=\"#top\">(Top)</a></h2>"
  echo "<table class=\"table table-striped\">"
  echo "<thead><tr>"
  head -1 "$input_file" | awk -F '|' '{for(i=1; i<=NF; i++) printf "<th>%s</th>", $i}'
  echo "</tr></thead>"
  echo "<tbody>"
  tail -n +3 "$input_file" | awk -F '|' '{print "<tr>"; for(i=1; i<=NF; i++) printf "<td>%s</td>", $i; print "</tr>"}'
  echo "</tbody>"
  echo "</table>"
}

# Query to list all roles
roles_query="SELECT rolname, rolsuper, rolinherit, rolcreaterole, rolcreatedb, rolcanlogin, rolreplication, rolbypassrls FROM pg_roles;"
run_query "$roles_query" $USERS_FILE

# Query to list all table privileges
table_privileges_query="SELECT grantee, table_catalog, table_schema, table_name, privilege_type FROM information_schema.role_table_grants ORDER BY grantee, table_schema, table_name, privilege_type;"
run_query "$table_privileges_query" $TABLE_PRIVILEGES_FILE

# Query to list all schema privileges
schema_privileges_query="SELECT nspname AS schema_name,
       pg_catalog.pg_get_userbyid(nspowner) AS owner,
       array_to_string(nspacl, ',') AS privileges
FROM pg_catalog.pg_namespace
ORDER BY schema_name;"
run_query "$schema_privileges_query" $SCHEMA_PRIVILEGES_FILE

# Query to list all role memberships
role_memberships_query="SELECT r1.rolname AS role, r2.rolname AS member, r3.rolname AS grantor FROM pg_auth_members JOIN pg_roles r1 ON roleid = r1.oid JOIN pg_roles r2 ON member = r2.oid JOIN pg_roles r3 ON grantor = r3.oid ORDER BY role, member;"
run_query "$role_memberships_query" $ROLE_MEMBERSHIPS_FILE

# Query to list all database privileges
database_privileges_query="SELECT d.datname AS database, r.rolname AS role, pg_catalog.has_database_privilege(r.rolname, d.datname, 'CONNECT') AS connect, pg_catalog.has_database_privilege(r.rolname, d.datname, 'CREATE') AS create, pg_catalog.has_database_privilege(r.rolname, d.datname, 'TEMPORARY') AS temporary, pg_catalog.has_database_privilege(r.rolname, d.datname, 'TEMP') AS temp FROM pg_database d JOIN pg_roles r ON pg_catalog.has_database_privilege(r.rolname, d.datname, 'CONNECT') ORDER BY d.datname, r.rolname;"
run_query "$database_privileges_query" $DATABASE_PRIVILEGES_FILE

# Query to check user privileges for migrations in the specified schema
migration_privileges_query="
SELECT '$PGSCHEMA' AS schema_name,
       u.usename AS username,
       t.tablename AS table_name,
       has_table_privilege(u.usename, '$PGSCHEMA.' || t.tablename, 'INSERT') AS can_insert,
       has_table_privilege(u.usename, '$PGSCHEMA.' || t.tablename, 'UPDATE') AS can_update,
       has_table_privilege(u.usename, '$PGSCHEMA.' || t.tablename, 'DELETE') AS can_delete
FROM pg_user u,
     (SELECT tablename FROM pg_tables WHERE schemaname = '$PGSCHEMA') t
ORDER BY u.usename, t.tablename;"
run_query "$migration_privileges_query" $MIGRATION_PRIVILEGES_FILE

# Debugging: Check if there are tables in the specified schema
schema_tables_query="SELECT tablename FROM pg_tables WHERE schemaname = '$PGSCHEMA';"
run_query "$schema_tables_query" "$REPORTS_DIR/${PROJECT_NAME}_schema_tables_${TODAY}.txt"

# Create HTML report
echo "<!DOCTYPE html>
<html lang=\"en\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <title>${PROJECT_NAME} Report ${TODAY}</title>
    <link href=\"https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/css/bootstrap.min.css\" rel=\"stylesheet\">
</head>
<body>
    <div class=\"container\">
        <h1 id=\"top\">${PROJECT_NAME} Report ${TODAY}</h1>
        <ul>
            <li><a href=\"#users-and-roles\">Users and Roles</a></li>
            <li><a href=\"#table-privileges\">Table Privileges</a></li>
            <li><a href=\"#schema-privileges\">Schema Privileges</a></li>
            <li><a href=\"#role-memberships\">Role Memberships</a></li>
            <li><a href=\"#database-privileges\">Database Privileges</a></li>
            <li><a href=\"#migration-privileges\">Migration Privileges</a></li>
        </ul>" > $HTML_REPORT_FILE

convert_to_html_table $USERS_FILE "Users and Roles" "users-and-roles" >> $HTML_REPORT_FILE
convert_to_html_table $TABLE_PRIVILEGES_FILE "Table Privileges" "table-privileges" >> $HTML_REPORT_FILE
convert_to_html_table $SCHEMA_PRIVILEGES_FILE "Schema Privileges" "schema-privileges" >> $HTML_REPORT_FILE
convert_to_html_table $ROLE_MEMBERSHIPS_FILE "Role Memberships" "role-memberships" >> $HTML_REPORT_FILE
convert_to_html_table $DATABASE_PRIVILEGES_FILE "Database Privileges" "database-privileges" >> $HTML_REPORT_FILE
convert_to_html_table $MIGRATION_PRIVILEGES_FILE "Migration Privileges" "migration-privileges" >> $HTML_REPORT_FILE

echo "    </div>
</body>
</html>" >> $HTML_REPORT_FILE

echo "All queries executed and results saved."
