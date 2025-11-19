import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response
import gleam/int
import gleam/io
import gleam/list

import gleam/string
import logging
import mist

import reddit_api
import reddit_engine
import reddit_user
import types.{type Post, type RedditMsg, type UserMsg, GetFeed, ReceiveFeed}

fn parse_int_or_default(s: String, default: Int) -> Int {
  case int.parse(s) {
    Ok(i) -> i
    _ -> default
  }
}

fn parse_subscriptions_csv(csv: String) -> List(Int) {
  // reddit_api.parse_subscriptions returns List(String) — convert to ints here
  let strs = reddit_api.parse_subscriptions(csv)
  list.map(strs, fn(ss) { parse_int_or_default(ss, -1) })
}

// Very small JSON helpers used for the example. Not a full JSON library.
fn json_escape(s: String) -> String {
  string.replace(s, "\"", "\\\"")
}

fn post_to_json(post: Post) -> String {
  // post fields: id, text, up_votes, down_votes, children, poster, karma
  let children_json = posts_list_to_json(post.children)
  "{\"id\":"
  <> int.to_string(post.id)
  <> ",\"text\":\""
  <> json_escape(post.text)
  <> "\",\"up_votes\":"
  <> int.to_string(post.up_votes)
  <> ",\"down_votes\":"
  <> int.to_string(post.down_votes)
  <> ",\"karma\":"
  <> int.to_string(post.karma)
  <> ",\"children\":"
  <> children_json
  <> "}"
}

fn posts_list_to_json(posts: List(Post)) -> String {
  let post_jsons = list.map(posts, post_to_json)
  "[" <> string.join(post_jsons, ",") <> "]"
}

fn posts_to_json(subreddits: List(List(Post))) -> String {
  let tail = list.map(subreddits, posts_list_to_json)
  "[" <> string.join(tail, ",") <> "]"
}

// Naive JSON extractors used for the example only.
fn extract_int_field(body: String, key: String, default: Int) -> Int {
  case string.split_once(body, "\"" <> key <> "\"") {
    Ok(#(_, rest)) -> {
      case string.split_once(rest, ":") {
        Ok(#(_, after_colon)) -> {
          let trimmed = string.trim(after_colon)
          case string.split_once(trimmed, ",") {
            Ok(#(val, _)) ->
              case int.parse(string.trim(val)) {
                Ok(i) -> i
                _ -> default
              }
            Error(_) ->
              case string.split_once(trimmed, "}") {
                Ok(#(val, _)) ->
                  case int.parse(string.trim(val)) {
                    Ok(i) -> i
                    _ -> default
                  }
                _ -> default
              }
          }
        }
        Error(_) -> default
      }
    }
    Error(_) -> default
  }
}

fn extract_string_field(body: String, key: String, default: String) -> String {
  case string.split_once(body, "\"" <> key <> "\"") {
    Ok(#(_, rest)) -> {
      case string.split_once(rest, ":") {
        Ok(#(_, after_colon)) -> {
          let t = string.trim(after_colon)
          case string.split_once(t, "\"") {
            Ok(#(_, rest2)) ->
              case string.split_once(rest2, "\"") {
                Ok(#(value, _)) -> value
                _ -> default
              }
            Error(_) -> default
          }
        }
        Error(_) -> default
      }
    }
    Error(_) -> default
  }
}

fn extract_bool_field(body: String, key: String, default: Bool) -> Bool {
  case string.split_once(body, "\"" <> key <> "\"") {
    Ok(#(_, rest)) -> {
      case string.split_once(rest, ":") {
        Ok(#(_, after_colon)) -> {
          let t = string.trim(after_colon)
          case string.starts_with(t, "true") {
            True -> True
            _ ->
              case string.starts_with(t, "false") {
                True -> False
                _ -> default
              }
          }
        }
        Error(_) -> default
      }
    }
    Error(_) -> default
  }
}

fn handle_request(
  req: Request(mist.Connection),
  engine: process.Subject(RedditMsg),
) -> response.Response(mist.ResponseData) {
  let segments = request.path_segments(req)

  case segments {
    ["create_post"] -> {
      io.println("Making new post!")
      case mist.read_body(req, 1024 * 16) {
        Ok(r) -> {
          case bit_array.to_string(r.body) {
            Ok(body_str) -> {
              let subreddit = extract_int_field(body_str, "subreddit", -1)
              let parent = extract_int_field(body_str, "parent", -1)
              let poster_id = extract_int_field(body_str, "poster", 0)
              let text = extract_string_field(body_str, "text", "")

              let poster = reddit_user.start_user(poster_id, engine)
              reddit_api.create_post(engine, subreddit, parent, text, poster)

              response.new(202)
              |> response.set_body(
                mist.Bytes(bytes_tree.from_string("Accepted")),
              )
            }
            Error(_) ->
              response.new(400)
              |> response.set_body(
                mist.Bytes(bytes_tree.from_string("Bad request")),
              )
          }
        }
        Error(_) ->
          response.new(400)
          |> response.set_body(
            mist.Bytes(bytes_tree.from_string("Bad request")),
          )
      }
    }

    ["create_subreddit"] -> {
      reddit_api.create_subreddit(engine)
      response.new(201)
      |> response.set_body(mist.Bytes(bytes_tree.from_string("Created")))
    }

    ["vote"] -> {
      case mist.read_body(req, 1024 * 4) {
        Ok(r) -> {
          case bit_array.to_string(r.body) {
            Ok(body) -> {
              let subreddit = extract_int_field(body, "subreddit", -1)
              let post_id = extract_int_field(body, "post_id", -1)
              let up = extract_bool_field(body, "up", True)
              reddit_api.vote(engine, subreddit, post_id, up)
              response.new(200)
              |> response.set_body(mist.Bytes(bytes_tree.from_string("OK")))
            }
            Error(_) ->
              response.new(400)
              |> response.set_body(
                mist.Bytes(bytes_tree.from_string("Bad request")),
              )
          }
        }
        Error(_) ->
          response.new(400)
          |> response.set_body(
            mist.Bytes(bytes_tree.from_string("Bad request")),
          )
      }
    }

    ["feed_sync"] -> {
      case mist.read_body(req, 1024 * 8) {
        Ok(r) -> {
          case bit_array.to_string(r.body) {
            Ok(body) -> {
              let subs_csv = extract_string_field(body, "subs_csv", "")
              let subs = parse_subscriptions_csv(subs_csv)
              let k = extract_int_field(body, "k", 3)

              let reply: process.Subject(UserMsg) = process.new_subject()
              //let assert Ok(result) = actor.call(engine, 10_000, GetFeed(subs, k, reply))
              process.send(engine, GetFeed(subs, k, reply))

              case process.receive(reply, 5000) {
                Ok(msg) -> {
                  case msg {
                    ReceiveFeed(posts) -> {
                      let body_json = posts_to_json(posts)
                      io.println(body_json)
                      io.println("Requesting Feed")
                      response.new(200)
                      |> response.set_header("content-type", "application/json")
                      |> response.set_body(
                        mist.Bytes(bytes_tree.from_string(body_json)),
                      )
                    }
                    _ ->
                      response.new(500)
                      |> response.set_body(
                        mist.Bytes(bytes_tree.from_string("Unexpected reply")),
                      )
                  }
                }
                Error(_) ->
                  response.new(504)
                  |> response.set_body(
                    mist.Bytes(bytes_tree.from_string("Gateway Timeout")),
                  )
              }
            }
            Error(_) ->
              response.new(400)
              |> response.set_body(
                mist.Bytes(bytes_tree.from_string("Bad request")),
              )
          }
        }
        Error(_) ->
          response.new(400)
          |> response.set_body(
            mist.Bytes(bytes_tree.from_string("Bad request")),
          )
      }
    }

    _ ->
      response.new(404)
      |> response.set_body(mist.Bytes(bytes_tree.from_string("Not found")))
  }
}

pub fn main() {
  logging.configure()
  logging.set_level(logging.Info)

  let engine = reddit_engine.start_reddit_engine()

  let app = fn(req: Request(mist.Connection)) -> response.Response(
    mist.ResponseData,
  ) {
    handle_request(req, engine)
  }

  let _ =
    app
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(8080)
    |> mist.start

  io.println("Server started on :8080")
  process.sleep_forever()
}
