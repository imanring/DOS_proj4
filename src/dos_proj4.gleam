import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor

pub type UserMsg {
  MakePost(Int, Int, String)
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
) {
  case posts {
    [] -> #([], False)
    [post, ..rest] -> {
      case post.id == post_id {
        True -> #([update_fn(post), ..rest], True)
        False -> {
          // Search in children
          let #(updated_children, found) =
            update_post_by_id(post.children, post_id, update_fn)
          case found {
            True -> #([Post(..post, children: updated_children), ..rest], True)
            False -> {
              // Search in siblings
              let #(updated_siblings, found) =
                update_post_by_id(post.children, post_id, update_fn)
              #([post, ..updated_siblings], found)
            }
          }
        }
      }
    }
  }
}

pub fn engine_handler(
  msg: RedditMsg,
  state: RedditEngineState,
) -> actor.Next(RedditEngineState, RedditMsg) {
  case msg {
    NewPost(subreddit_id, parent_post_id, text, poster) -> {
      let rslt = list.find(state.subreddits, fn(sr) { sr.id == subreddit_id })
      case rslt {
        Ok(subreddit) -> {
          let new_post =
            Post(
              id: subreddit.max_post_id + 1,
              text: text,
              up_votes: 0,
              down_votes: 0,
              children: [],
              poster: poster,
            )

          let updated_subreddit = case parent_post_id {
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
                    // add the comment as a child post
                    Post(..parent_post, children: [
                      new_post,
                      ..parent_post.children
                    ])
                  },
                )
              SubReddit(
                ..subreddit,
                posts: updated_posts,
                max_post_id: subreddit.max_post_id + 1,
              )
            }
          }
          // Handle new post
          actor.continue(
            RedditEngineState(
              ..state,
              subreddits: list.map(
                state.subreddits,
                // Update the subreddit in the list
                fn(sr) {
                  case sr.id == subreddit_id {
                    True -> updated_subreddit
                    False -> sr
                  }
                },
              ),
            ),
          )
        }
        Error(_) -> {
          // Subreddit not found, continue with the same state
          actor.continue(state)
        }
      }
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
      // Handle voting
      actor.continue(state)
    }
    GetFeed(subscriptions) -> {
      // Handle feed retrieval
      actor.continue(state)
    }
  }
}

pub fn main() -> Nil {
  io.println("Hello from dos_proj4!")
}
