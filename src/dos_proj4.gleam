import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor

pub type UserMsg {
  MakePost(Int, Int, String)
}

// Placeholder for User Actor (AI generated)
fn start_user_actor(user_id: Int) -> process.Subject(UserMsg) {
  let builder =
    actor.new(Nil)
    |> actor.on_message(fn(state: Nil, msg: UserMsg) -> actor.Next(Nil, UserMsg) {
      case msg {
        MakePost(subreddit_id, _parent_post_id, text) -> {
          // In a full implementation, the user actor would send this to the Reddit engine
          io.println(
            "User "
            <> int.to_string(user_id)
            <> " making post in subreddit "
            <> int.to_string(subreddit_id)
            <> ": "
            <> text,
          )
          actor.continue(state)
        }
      }
    })
  let assert Ok(new_actor) = actor.start(builder)
  new_actor.data
}

// Reddit Engine
pub type Post {
  Post(
    id: Int,
    text: String,
    up_votes: Int,
    down_votes: Int,
    children: List(Post),
    poster: process.Subject(UserMsg),
    karma: Int,
    // up_votes - down_votes + children karma + # of children
  )
}

pub type SubReddit {
  SubReddit(id: Int, name: String, posts: List(Post), max_post_id: Int)
}

pub type RedditMsg {
  NewPost(Int, Int, String, process.Subject(UserMsg))
  NewSubReddit
  CastVote(subreddit_id: Int, post_id: Int, upvote: Bool)
  // True for upvote, False for downvote
  GetFeed(subscriptions: List(Int))
}

pub type RedditEngineState {
  RedditEngineState(subreddits: List(SubReddit), max_subreddit_id: Int)
}

fn update_post_by_id(
  posts: List(Post),
  post_id: Int,
  update_fn: fn(Post) -> Post,
  parent_karma_update: Int,
) {
  case posts {
    [] -> #([], False)
    [post, ..rest] -> {
      case post.id == post_id {
        True -> #([update_fn(post), ..rest], True)
        False -> {
          // Search in children
          let #(updated_children, found) =
            update_post_by_id(
              post.children,
              post_id,
              update_fn,
              parent_karma_update,
            )
          case found {
            True -> {
              // update senders karma
              // process.send(post.poster, UpdateKarma(parent_karma_update))
              // to do update karma here
              #(
                [
                  Post(
                    ..post,
                    children: updated_children,
                    karma: post.karma + parent_karma_update,
                  ),
                  ..rest
                ],
                True,
              )
            }
            False -> {
              // Search in siblings
              let #(updated_siblings, found) =
                update_post_by_id(rest, post_id, update_fn, parent_karma_update)
              #([post, ..updated_siblings], found)
            }
          }
        }
      }
    }
  }
}

fn update_subreddit_by_id(
  subreddits: List(SubReddit),
  subreddit_id: Int,
  update_fn: fn(SubReddit) -> SubReddit,
) {
  case subreddits {
    [] -> #([], False)
    [sr, ..rest] -> {
      case sr.id == subreddit_id {
        True -> #([update_fn(sr), ..rest], True)
        False -> {
          let #(updated_rest, found) =
            update_subreddit_by_id(rest, subreddit_id, update_fn)
          #([sr, ..updated_rest], found)
        }
      }
    }
  }
}

pub fn insert_post(xs: List(Post), new_item: Post) -> List(Post) {
  case xs {
    [] -> [new_item]
    [head, ..tail] -> {
      // If the new item is smaller than or equal to the head,
      // it should be placed before the head.
      case new_item.karma <= head.karma {
        True -> [new_item, ..xs]
        False -> [head, ..insert_post(tail, new_item)]
      }
    }
  }
}

// print subreddit feed (for testing)
fn print_subreddit_feed(posts: List(Post), indent: String) -> Nil {
  case posts {
    [] -> Nil
    [post, ..rest] -> {
      io.println(
        indent
        <> "Post ID: "
        <> int.to_string(post.id)
        <> ", Text: "
        <> post.text
        <> ", Upvotes: "
        <> int.to_string(post.up_votes)
        <> ", Downvotes: "
        <> int.to_string(post.down_votes)
        <> ", Karma: "
        <> int.to_string(post.karma),
      )
      let _ = print_subreddit_feed(post.children, indent <> "  ")
      print_subreddit_feed(rest, indent)
    }
  }
}

pub fn engine_handler(
  state: RedditEngineState,
  msg: RedditMsg,
) -> actor.Next(RedditEngineState, RedditMsg) {
  case msg {
    NewPost(subreddit_id, parent_post_id, text, poster) -> {
      // Handle new post or reply
      let #(updated_subreddit, _) =
        update_subreddit_by_id(state.subreddits, subreddit_id, fn(subreddit) {
          let new_post =
            Post(
              id: subreddit.max_post_id + 1,
              text: text,
              up_votes: 0,
              down_votes: 0,
              children: [],
              poster: poster,
              karma: 0,
            )
          case parent_post_id {
            -1 -> {
              // New post
              SubReddit(
                ..subreddit,
                posts: [new_post, ..subreddit.posts],
                max_post_id: subreddit.max_post_id + 1,
              )
            }
            _ -> {
              // Reply to existing post
              // Find and update the parent post
              let #(updated_posts, _) =
                update_post_by_id(
                  subreddit.posts,
                  parent_post_id,
                  fn(parent_post) {
                    // process.send(parent_post.poster, UpdateKarma(1))
                    // add the comment as a child post
                    Post(
                      ..parent_post,
                      children: [new_post, ..parent_post.children],
                      karma: parent_post.karma + 1,
                    )
                  },
                  1,
                  // increase parent's karma by 1 for new child
                )
              SubReddit(
                ..subreddit,
                posts: updated_posts,
                max_post_id: subreddit.max_post_id + 1,
              )
            }
          }
        })
      actor.continue(RedditEngineState(..state, subreddits: updated_subreddit))
    }
    NewSubReddit -> {
      // Handle new subreddit creation
      actor.continue(RedditEngineState(
        subreddits: [
          SubReddit(
            id: state.max_subreddit_id + 1,
            name: "subreddit_" <> int.to_string(state.max_subreddit_id + 1),
            posts: [],
            max_post_id: 0,
          ),
          ..state.subreddits
        ],
        max_subreddit_id: state.max_subreddit_id + 1,
      ))
    }
    CastVote(subreddit_id, post_id, upvote) -> {
      let vote = case upvote {
        True -> 1
        False -> -1
      }
      // Handle voting
      let #(updated_subreddits, _) =
        update_subreddit_by_id(state.subreddits, subreddit_id, fn(sr) {
          let #(updated_posts, _) =
            update_post_by_id(
              sr.posts,
              post_id,
              fn(post) {
                // process.send(post.poster, UpdateKarma(vote))
                case upvote {
                  True ->
                    Post(
                      ..post,
                      up_votes: post.up_votes + 1,
                      karma: post.karma + 1,
                    )
                  False ->
                    Post(
                      ..post,
                      down_votes: post.down_votes + 1,
                      karma: post.karma - 1,
                    )
                }
              },
              // change in karma
              vote,
            )
          SubReddit(..sr, posts: updated_posts)
        })
      actor.continue(RedditEngineState(..state, subreddits: updated_subreddits))
    }
    GetFeed(subscriptions) -> {
      // Handle feed retrieval
      // For simplicity, just print the first subreddits' posts
      case list.first(state.subreddits) {
        Ok(first) -> {
          io.println("Feed for subreddit: " <> first.name)
          print_subreddit_feed(
            list.sort(first.posts, fn(p1, p2) {
              int.compare(p2.karma, p1.karma)
            }),
            "",
          )
        }
        Error(_) -> io.println("No subreddits available")
      }
      let _subreddits =
        list.filter(state.subreddits, fn(sr) {
          list.contains(subscriptions, sr.id)
        })
      // send subreddits back to requester (not implemented)
      actor.continue(state)
    }
  }
}

pub fn start_reddit_engine() -> process.Subject(RedditMsg) {
  let builder =
    actor.new(RedditEngineState(subreddits: [], max_subreddit_id: 0))
    |> actor.on_message(engine_handler)
  let assert Ok(new_actor) = actor.start(builder)
  new_actor.data
}

fn get_zipf(i: Float, u: Float) {
  case u <. 0.0 {
    True -> i -. 1.0
    False -> {
      get_zipf(i +. 1.0, u -. 1.0 /. i)
    }
  }
}

fn get_zipf_list(size: Int, hn: Float, result: List(Int)) -> List(Int) {
  case size <= 0 {
    True -> result
    False -> {
      let u = float.random() *. hn
      get_zipf_list(size - 1, hn, [float.round(get_zipf(1.0, u)), ..result])
    }
  }
}

fn gen_zipf(n: Int, size: Int) -> List(Int) {
  let denom =
    list.fold(list.range(1, n), 0.0, fn(ac, k) { ac +. 1.0 /. int.to_float(k) })
  get_zipf_list(size, denom, [])
}

pub fn main() {
  let x = gen_zipf(10, 50)
  echo x
  let reddit_engine = start_reddit_engine()
  let user1 = start_user_actor(1)
  process.send(reddit_engine, NewSubReddit)
  process.send(reddit_engine, NewPost(1, -1, "Is this thing on?", user1))
  process.send(reddit_engine, NewPost(1, -1, "Hello, Reddit!", user1))
  process.send(reddit_engine, CastVote(1, 2, True))
  process.send(reddit_engine, NewPost(1, 2, "What a great post!", user1))
  process.send(reddit_engine, GetFeed([]))
  process.sleep(1000)
}
