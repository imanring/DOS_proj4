import gleam/erlang/process
import gleam/list
// Int parsing is intentionally left to the HTTP handler to keep helpers
// framework-agnostic; handlers can convert strings to ints using their
// chosen JSON/parser helpers.
import gleam/string
import gleam/io
import types.{
  type RedditMsg, type UserMsg, NewPost, NewSubReddit, CastVote, GetFeed,
}

// Lightweight, framework-agnostic API helpers for the Reddit engine.
// These functions do not depend on a specific HTTP library so they can
// be easily wired into `mist` or `wisp` route handlers.

// Create a new post (or reply) in a subreddit.
pub fn create_post(
  engine: process.Subject(RedditMsg),
  subreddit_id: Int,
  parent_post_id: Int,
  text: String,
  poster: process.Subject(UserMsg),
) {
  process.send(engine, NewPost(subreddit_id, parent_post_id, text, poster))
}

// Create a new subreddit.
pub fn create_subreddit(engine: process.Subject(RedditMsg)) {
  process.send(engine, NewSubReddit)
}

// Cast a vote on a post.
pub fn vote(engine: process.Subject(RedditMsg), subreddit_id: Int, post_id: Int, upvote: Bool) {
  process.send(engine, CastVote(subreddit_id, post_id, upvote))
}

// Request a feed from the engine. This is asynchronous: the engine will
// send `ReceiveFeed` to the `reply_to` subject you provide. The API
// caller (HTTP handler) is responsible for either providing a live
// `User` actor to receive the reply, or for bridging the reply back to
// the HTTP response channel.
pub fn request_feed(
  engine: process.Subject(RedditMsg),
  subscriptions: List(Int),
  k: Int,
  reply_to: process.Subject(UserMsg),
) {
  process.send(engine, GetFeed(subscriptions, k, reply_to))
}

// Helper: parse a comma-separated list of ints in a query parameter.
pub fn parse_subscriptions(csv: String) -> List(String) {
  case string.trim(csv) {
    "" -> []
    _ -> {
      let parts = string.split(csv, ",")
      list.map(parts, fn(s) { string.trim(s) })
    }
  }
}

// Example wiring notes (for README or quick copy):
// - With Mist: in your Mist route handler parse JSON/body/query into
//   the simple arguments and call the functions above. For create_post
//   you'll need a `process.Subject(UserMsg)` to act as the poster (you
//   can use an existing user actor or create one via `reddit_user.start_user`).
// - For synchronous HTTP responses to `request_feed`, create a short-lived
//   user actor which forwards the `ReceiveFeed` message back to the
//   HTTP handler (for example by sending it to a mailbox linked to the
//   request), or return 202 Accepted and have clients poll or use a
//   websocket for push updates.

// Minimal debug helpers for CLI/dev use.
pub fn example_create_post_cli(
  engine: process.Subject(RedditMsg),
  poster: process.Subject(UserMsg),
) {
  io.println("Creating example post in subreddit 0")
  create_post(engine, 0, -1, "Hello from API CLI", poster)
}
