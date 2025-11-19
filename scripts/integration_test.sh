#!/usr/bin/env bash
set -euo pipefail

# Simple integration test runner for the dos_proj4 Mist server.
# It tries to start the server with `gleam run` (or `rebar3 shell` fallback),
# waits for the port to accept connections, runs a few requests, then stops the server.

echo "Integration test: starting server..."
SERVER_PID=""

if command -v gleam >/dev/null 2>&1; then
  gleam run &
  SERVER_PID=$!
  echo "Started server (gleam) PID=$SERVER_PID"
elif command -v rebar3 >/dev/null 2>&1; then
  rebar3 shell &
  SERVER_PID=$!
  echo "Started server (rebar3) PID=$SERVER_PID"
else
  echo "No 'gleam' or 'rebar3' command found. Please start the server manually and re-run this script."
  exit 2
fi

cleanup() {
  echo "Stopping server $SERVER_PID"
  kill "$SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT

# Wait for server to accept connections on port 8080
echo "Waiting for server to accept connections on http://127.0.0.1:8080/..."
for i in $(seq 1 20); do
  if curl -sS -o /dev/null http://127.0.0.1:8080/; then
    break
  fi
  sleep 0.5
done

# 1) Create subreddit
echo "1) Create subreddit"
HTTP_CODE=$(curl -s -o /tmp/test_create_sub.out -w "%{http_code}" -X POST http://127.0.0.1:8080/create_subreddit)
cat /tmp/test_create_sub.out
if [ "$HTTP_CODE" != "201" ]; then
  echo "Create subreddit failed (code $HTTP_CODE)"
  exit 1
fi

# 2) Create post
echo "2) Create post"
HTTP_CODE=$(curl -s -o /tmp/test_create_post.out -w "%{http_code}" -X POST -H "Content-Type: application/json" \
  -d '{"subreddit":1,"parent":-1,"poster":123,"text":"Integration test post"}' \
  http://127.0.0.1:8080/create_post)
cat /tmp/test_create_post.out
if [ "$HTTP_CODE" != "202" ]; then
  echo "Create post failed (code $HTTP_CODE)"
  exit 1
fi

# 3) Vote
echo "3) Vote"
HTTP_CODE=$(curl -s -o /tmp/test_vote.out -w "%{http_code}" -X POST -H "Content-Type: application/json" \
  -d '{"subreddit":1,"post_id":1,"up":true}' \
  http://127.0.0.1:8080/vote)
cat /tmp/test_vote.out
if [ "$HTTP_CODE" != "200" ]; then
  echo "Vote failed (code $HTTP_CODE)"
  exit 1
fi

# 4) Feed sync
echo "4) Feed sync"
HTTP_CODE=$(curl -s -o /tmp/test_feed.out -w "%{http_code}" -X POST -H "Content-Type: application/json" \
  -d '{"subs_csv":"1","k":10}' \
  http://127.0.0.1:8080/feed_sync)

echo "HTTP code: $HTTP_CODE"
echo "Body:"
cat /tmp/test_feed.out
if [ "$HTTP_CODE" != "200" ]; then
  echo "Feed sync failed (code $HTTP_CODE)"
  exit 1
fi

echo "Integration tests passed."
exit 0
