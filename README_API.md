Reddit Engine HTTP API (Mist)

This project contains a simple Mist-based HTTP server (`src/server.gleam`) that
wires the in-process Reddit engine to HTTP endpoints. The server currently uses
simple path-segment based arguments to keep the example short.

Endpoints (examples):

- Create a post (top-level or reply):
  POST /create_post/<subreddit>/<parent>/<poster>/<text>
  - `subreddit`: Int id of subreddit (-1 for none)
  - `parent`: Int id of parent post (-1 for top-level)
  - `poster`: Int id of the poster (used to start a user actor)
  - `text`: post text (URL-encoded in the path segment)
  - Example: POST /posts/0/-1/0/Hello%20world

- Create a subreddit:
  POST /subreddits

- Vote on a post:
  POST /vote/<subreddit>/<post_id>/up
  POST /vote/<subreddit>/<post_id>/down

- Request a feed (asynchronous delivery):
  GET /feed/<subs_csv>/<k>/<requester_id>
  - `subs_csv`: comma-separated subreddit ids (e.g. "0,1,2")
  - `k`: number of posts per subreddit
  - `requester_id`: user id that will receive the `ReceiveFeed` message
  - This endpoint returns 202 Accepted and a `User` actor will receive the
    feed and print it to the console in the current example.

Notes on synchronous feed responses

The example server returns feed requests asynchronously (202 Accepted). To
provide a synchronous HTTP response with the feed contents you can:

1. Create a short-lived `User` actor that will receive `ReceiveFeed` from the
   engine. Have that actor forward the feed to a supervisor process or write it
   to a temporary storage slot keyed by the HTTP request ID.
2. Block the HTTP handler waiting for the feed to be available (poll the
   temporary storage or use a mailbox communication primitive). Be careful:
   blocking a handler ties up the request worker — prefer setting a reasonable
   timeout.
3. Alternatively use websockets and push the feed to the connected client when
   the `ReceiveFeed` arrives.

Running

Make sure `mist` and required packages are added to your project. From the
project root you can start the server with:

```sh
# if you have Gleam + rebar/OTP setup
gleam run -p src -m server
```

(Adjust the run command to match your local build/run setup.)

Next steps

- Improve parameter parsing (JSON body support, query params)
- Cache and reuse `User` actors rather than starting on every request
- Implement a proper synchronous bridge (short-lived actor + mailbox or websocket)
- Add more unit/integration tests that start the engine and verify behavior
