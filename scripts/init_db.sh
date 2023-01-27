#!/usr/bin/env bash
set -x
set -eo pipefail

# Check if psql is installed
  if ! [ -x "$(command -v psql)" ]; then
  echo >&2 "Error: psql is not installed."
  exit 1
fi

# Check if sqlx is installed
if ! [ -x "$(command -v sqlx)" ]; then
  echo >&2 "Error: sqlx is not installed."
  echo >&2 "Use:"
  echo >&2 " cargo install --version=0.5.7 sqlx-cli --no-default-features --features postgres"
  echo >&2 "to install it."
  exit 1
fi

# Check if a custom user has been set, otherwise default to 'postgres'
DB_USER=${POSTGRES_USER:=postgres}
# Check if a custom password has been set, otherwise default to 'password'
DB_PASSWORD="${POSTGRES_PASSWORD:=root}"
# Check if a custom database name has been set, otherwise default to 'newsletter'
DB_NAME="${POSTGRES_DB:=newsletter}"
# Check if a custom port has been set, otherwise default to '5432'
DB_PORT="${POSTGRES_PORT:=5432}"

# Launch postgres using Docker if flag `--with-docker` is passed
if [[ "$1" == "--with-docker" ]]; then
  docker run \
    -e POSTGRES_USER=${DB_USER} \
    -e POSTGRES_PASSWORD=${DB_PASSWORD} \
    -e POSTGRES_DB=${DB_NAME} \
    -p "${DB_PORT}":5432 \
    postgres -N 1000
  
  # Wait for postgres to be ready
  until PGPASSWORD=${DB_PASSWORD} psql -h localhost -U ${DB_USER} -p ${DB_PORT} -c '\q'; do
    >&2 echo "Postgres is unavailable - sleeping"
    sleep 1
  done

  >&2 echo "Postgres is up - executing command"
else
  # Check if postgres is already running
  if ! pg_isready -q -h localhost -p ${DB_PORT} -U ${DB_USER}; then
    echo "Postgres is not running"
    exit 1
  fi

  >&2 echo "Postgres is up - executing command"

  export DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/${DB_NAME}"
  # Create database if it doesn't exist
  if ! PGPASSWORD=${DB_PASSWORD} psql -h localhost -U ${DB_USER} -p ${DB_PORT} -lqt | cut -d \| -f 1 | grep -qw ${DB_NAME}; then
    sqlx database create
    >&2 echo "Database ${DB_NAME} created"
  else
    >&2 echo "Database ${DB_NAME} already exists"
  fi
fi

# Set DATABASE_URL environment variable if not already set
if [[ -z "${DATABASE_URL}" ]]; then
  export DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/${DB_NAME}"
fi

# Create create_subscriptions_table migration
# sqlx migrate add create_subscriptions_table
sqlx migrate run

>&2 echo "Postgres has been migrated, ready to go!"
