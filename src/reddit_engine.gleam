import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import types.{
  type Post, type RedditEngineState, type RedditMsg, type SubReddit, AddUser,
  CastVote, GetFeed, GetStats, GetUsers, NewPost, NewSubReddit, Post,
  ReceiveFeed, RedditEngineState, Search, SubReddit, Users,
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

pub fn engine_handler(
  state: RedditEngineState,
  msg: RedditMsg,
) -> actor.Next(RedditEngineState, RedditMsg) {
  case msg {
    NewPost(subreddit_id, parent_post_id, text, poster) -> {
      io.println("New post: " <> text)
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
      actor.continue(
        RedditEngineState(
          ..state,
          subreddits: updated_subreddit,
          total_msg: state.total_msg + 1,
        ),
      )
    }
    NewSubReddit(name) -> {
      io.println("NewSubReddit: " <> int.to_string(state.max_subreddit_id))
      // Handle new subreddit creation
      actor.continue(RedditEngineState(
        subreddits: [
          SubReddit(
            id: state.max_subreddit_id + 1,
            name: name,
            posts: [],
            max_post_id: -1,
          ),
          ..state.subreddits
        ],
        max_subreddit_id: state.max_subreddit_id + 1,
        total_msg: state.total_msg + 1,
        users: state.users,
      ))
    }
    CastVote(subreddit_id, post_id, upvote) -> {
      let vote = case upvote {
        True -> 1
        False -> -1
      }
      io.println(
        "Casting vote: "
        <> int.to_string(vote)
        <> ", post id: "
        <> int.to_string(post_id),
      )
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
      actor.continue(
        RedditEngineState(
          ..state,
          subreddits: updated_subreddits,
          total_msg: state.total_msg + 1,
        ),
      )
    }
    GetFeed(subscriptions, k, reply_to) -> {
      // get the top k posts from each subscription
      // Handle feed retrieval
      let subreddits =
        list.map(
          list.filter(state.subreddits, fn(sr) {
            list.contains(subscriptions, sr.id)
          }),
          fn(x) { list.take(x.posts, k) },
        )
      // send subreddits back to requester (not implemented)
      process.send(reply_to, ReceiveFeed(subreddits))
      actor.continue(RedditEngineState(..state, total_msg: state.total_msg + 1))
    }
    GetStats -> {
      io.println("Total messages: " <> int.to_string(state.total_msg))
      actor.continue(state)
    }
    AddUser(user_id, user) -> {
      io.println("Adding new user")
      actor.continue(
        RedditEngineState(
          ..state,
          users: [#(user_id, user), ..state.users],
          total_msg: state.total_msg + 1,
        ),
      )
    }
    GetUsers(reply_to) -> {
      process.send(reply_to, Users(state.users))
      actor.continue(RedditEngineState(..state, total_msg: state.total_msg + 1))
    }
    Search(name, k, reply_to) -> {
      let subreddits =
        list.map(
          list.filter(state.subreddits, fn(sr) { name == sr.name }),
          fn(x) { list.take(x.posts, k) },
        )
      process.send(reply_to, ReceiveFeed(subreddits))
      actor.continue(RedditEngineState(..state, total_msg: state.total_msg + 1))
    }
  }
}

pub fn start_reddit_engine() -> process.Subject(RedditMsg) {
  let builder =
    actor.new(
      RedditEngineState(
        subreddits: [],
        max_subreddit_id: -1,
        total_msg: 0,
        users: [],
      ),
    )
    |> actor.on_message(engine_handler)
  let assert Ok(new_actor) = actor.start(builder)
  new_actor.data
}
