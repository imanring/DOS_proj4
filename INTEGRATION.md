Connecting to the server (browser / curl) and running the integration tests

1) How to connect from your browser

- The server listens on port 8080 by default (0.0.0.0:8080).
- All provided endpoints are HTTP POST endpoints that expect JSON bodies.
- Browsers can't easily issue POST JSON from the address bar; use one of the following:
  - Postman / Insomnia / REST Client browser extension — easiest for manual testing.
  - The browser DevTools console with `fetch()` (example below).
  - A simple HTML page or curl (recommended for quick checks).

Example `fetch()` from the browser console (open DevTools → Console):

```js
fetch('http://localhost:8080/feed_sync', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ subs_csv: '1', k: 10 })
})
  .then(r => r.json())
  .then(data => console.log(data))
  .catch(err => console.error(err))
```

Note: the server's endpoints are:
- `POST /create_subreddit` -> creates a subreddit (returns 201)
- `POST /create_post` -> create a post, JSON: `{ "subreddit": Int, "parent": Int, "poster": Int, "text": String }` (returns 202)
- `POST /vote` -> cast a vote, JSON: `{ "subreddit": Int, "post_id": Int, "up": Bool }` (returns 200)
- `POST /feed_sync` -> synchronous feed, JSON: `{ "subs_csv": String, "k": Int }` (returns 200 with JSON feed, or 504 on timeout)

2) Using curl (example commands)

Create a subreddit:

```bash
curl -X POST http://127.0.0.1:8080/create_subreddit -v
```

Create a post:

```bash
curl -X POST http://127.0.0.1:8080/create_post \
  -H "Content-Type: application/json" \
  -d '{"subreddit":1,"parent":-1,"poster":123,"text":"Hello from curl"}'
```

Get a synchronous feed:

```bash
curl -X POST http://127.0.0.1:8080/feed_sync \
  -H "Content-Type: application/json" \
  -d '{"subs_csv":"1","k":10}'
```

3) Running the integration test script

- The repository includes `scripts/integration_test.sh` which:
  - Attempts to start the server using `gleam run` (or `rebar3 shell` fallback).
  - Waits for the server to accept connections on port 8080.
  - Runs the sequence: create subreddit, create post, vote, feed_sync, and validates HTTP codes.
  - Shuts down the started server.

Run it with:

```bash
bash scripts/integration_test.sh
```

If the script cannot auto-start the server because `gleam`/`rebar3` is not found, start the server manually and re-run the script. To start the server manually (typical options):

- If you have a Gleam toolchain installed and the project configured, you can run (from the `DOS_proj4` directory):

```bash
# If you normally run the app with Gleam
gleam run

# Or with rebar3 for the Erlang release
rebar3 shell
```

4) Notes and caveats

- The project's HTTP endpoints expect JSON but currently use simple, hand-written JSON extraction/encoding. For production or complex data, replace with a proper JSON encoder/decoder.
- `feed_sync` blocks waiting for the engine reply (the server waits up to 5 seconds). If you run many concurrent sync requests that block for long, consider switching to async push or increasing resources.

If you want, I can:
- Make the integration script more robust (auto-detect how you run the server and pass environment vars), or
- Add a tiny HTML test page you can open in your browser to send POST requests interactively.
