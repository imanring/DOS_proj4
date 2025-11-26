# Reddit Engine HTTP API (Mist)

This project contains a simple Mist-based HTTP server (`src/server.gleam`) that
wires the in-process Reddit engine to HTTP endpoints. The server currently uses
simple path-segment based arguments to keep the example short.

Endpoints:

- Create a post (top-level or reply):
  POST /create_post/
  - `subreddit`: Int id of subreddit (-1 for none)
  - `parent`: Int id of parent post (-1 for top-level)
  - `poster`: Int id of the poster (used to start a user actor)
  - `text`: post text (URL-encoded in the path segment)
  - Example: POST /posts/0/-1/0/Hello%20world

- Create a subreddit:
  POST /create_subreddit/
  - `name`: name of the subreddit

- Vote on a post:
  POST /vote/
  - `post_id`: id of the post to vote on
  - `subreddit`: id of the subreddit to vote on
  - `up`: boolean of whether the vote is up or down.

- Request a feed:
  POST /feed_sync/
  - `subs_csv`: comma-separated subreddit ids (e.g. "0,1,2")
  - `k`: number of posts per subreddit

- Search subreddits:
  POST /search/
  - `name`: name of the subreddit whose feed you want to look at.
  - `k`: number of posts per subreddit

- Create User:
  POST /create_user/
  - `user_id`: id of user you want to create

- Send Direct Message:
  POST /send_dm/
  - `sender_id`: user id of the sender
  - `receiver_id`: user id of the receiver
  - `message`: text of the message

Running

Make sure `mist` and required packages are added to your project. From the
project root you can start the server with:

```sh
gleam run
```