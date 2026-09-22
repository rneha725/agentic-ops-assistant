#!/usr/bin/env bash
#
# Starts a local Postgres + pgvector container for the rag project.
# Safe to run repeatedly: reuses the existing container if it's already
# running, starts it if it exists but is stopped, and only creates it
# from scratch the first time.

set -euo pipefail

CONTAINER_NAME="${RAG_PG_CONTAINER_NAME:-rag-postgres}"
IMAGE="${RAG_PG_IMAGE:-ankane/pgvector:latest}"
HOST_PORT="${RAG_PG_PORT:-5432}"
POSTGRES_USER="${RAG_PG_USER:-rag}"
POSTGRES_PASSWORD="${RAG_PG_PASSWORD:-rag}"
POSTGRES_DB="${RAG_PG_DB:-rag}"
VOLUME_NAME="${RAG_PG_VOLUME:-rag-postgres-data}"

if ! docker info >/dev/null 2>&1; then
  echo "Docker does not appear to be running. Start Docker Desktop and try again." >&2
  exit 1
fi

container_state="$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || true)"

if [[ "$container_state" == "running" ]]; then
  echo "Container '$CONTAINER_NAME' is already running."
elif [[ -n "$container_state" ]]; then
  echo "Container '$CONTAINER_NAME' exists but is stopped (state: $container_state). Starting it..."
  docker start "$CONTAINER_NAME" >/dev/null
else
  echo "Creating container '$CONTAINER_NAME' from image '$IMAGE'..."
  docker run -d \
    --name "$CONTAINER_NAME" \
    -e POSTGRES_USER="$POSTGRES_USER" \
    -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
    -e POSTGRES_DB="$POSTGRES_DB" \
    -p "${HOST_PORT}:5432" \
    -v "${VOLUME_NAME}:/var/lib/postgresql/data" \
    "$IMAGE" >/dev/null
fi

echo "Waiting for Postgres to accept connections..."
for _ in $(seq 1 30); do
  if docker exec "$CONTAINER_NAME" pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! docker exec "$CONTAINER_NAME" pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; then
  echo "Postgres did not become ready in time." >&2
  exit 1
fi

echo "Ensuring pgvector extension is enabled on '$POSTGRES_DB'..."
docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$CONTAINER_NAME" \
  psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS vector;" >/dev/null

echo "Postgres + pgvector ready at localhost:${HOST_PORT} (db=${POSTGRES_DB}, user=${POSTGRES_USER})"
