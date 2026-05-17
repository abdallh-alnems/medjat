#!/bin/bash

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_NAME:-medjat}"
DB_USER="${DB_USER:-root}"
DB_PASS="${DB_PASS:-}"

echo "Running Medjat migrations..."
echo "Database: ${DB_NAME}@${DB_HOST}:${DB_PORT}"

mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USER}" "${DB_PASS:+-p${DB_PASS}}" "${DB_NAME}" < "$(dirname "$0")/schema.sql"

if [ $? -eq 0 ]; then
    echo "✓ Schema applied successfully"
else
    echo "✗ Migration failed"
    exit 1
fi

for file in "$(dirname "$0")"/2*.sql; do
    if [ -f "$file" ]; then
        echo "Running: $(basename "$file")"
        mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USER}" "${DB_PASS:+-p${DB_PASS}}" "${DB_NAME}" < "$file"
        if [ $? -eq 0 ]; then
            echo "  ✓ $(basename "$file") applied"
        else
            echo "  ✗ $(basename "$file") failed"
        fi
    fi
done

echo "Done."
