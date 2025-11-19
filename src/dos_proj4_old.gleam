import argv
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import reddit_engine.{start_reddit_engine}
import reddit_user.{start_user}
import types.{
  type RedditMsg, type UserMsg, MakePost, NewSubReddit, RequestFeed, SendDM,
  Subscribe, Vote,
}

// Simulator
fn register_users(
  num: Int,
  engine: process.Subject(RedditMsg),
  users: List(process.Subject(UserMsg)),
) {
  case num {
    0 -> {
      io.println(
        "New user(s) registered. Now there are "
        <> int.to_string(list.length(users))
        <> " users.",
      )
      list.reverse(users)
    }
    _ -> {
      let user = start_user(num - 1, engine)
      register_users(num - 1, engine, list.append(users, [user]))
    }
  }
}

// pub fn random_action(
//   user: process.Subject(UserMsg),
//   receiver: process.Subject(UserMsg),
// ) {
//   // generate a random action
//   let seed = int.random(5)
//   // A simple template, to be completed
//   case seed {
//     0 -> process.send(user, RequestFeed(user))
//     1 -> process.send(user, SendDM(receiver, "Hi there!"))
//     // For simplicity the sr_id and post_id are all set to 0 here
//     2 -> process.send(user, MakePost(0, -1, "This is a Post.", user))
//     3 -> process.send(user, Vote(0, 0, True))
//     _ -> process.send(user, Subscribe(0))
//   }
// }

fn random_element(users: List(a)) -> a {
  let len = list.length(users)
  let index = int.random(len - 1)
  let remaining = list.drop(users, index)
  let assert Ok(user) = list.first(remaining)
  user
}

fn register_subreddits(engine, num: Int) {
  case num > 0 {
    True -> process.send(engine, NewSubReddit)
    False -> register_subreddits(engine, num - 1)
  }
}

fn user_subscribe_subreddits(users, k, hn, n, avg_num_subs) {
  case users {
    [] -> Nil
    [head, ..tail] -> {
      case k {
        0 -> user_subscribe_subreddits(tail, n, hn, n, avg_num_subs)
        _ -> {
          let x = float.random()
          case x <=. avg_num_subs /. { int.to_float(k) *. hn } {
            True -> process.send(head, Subscribe(k - 1))
            False -> Nil
          }
          user_subscribe_subreddits(users, k - 1, hn, n, avg_num_subs)
        }
      }
    }
  }
}

// A simple simulation showing basic functionality of the engine and users.
fn run_demo(num_users: Int) {
  let engine = start_reddit_engine()
  let users = register_users(num_users, engine, [])
  let assert Ok(user) = list.first(users)
  let assert Ok(receiver) = list.last(users)
  process.send(user, SendDM(receiver, "Hi there!"))
  process.send(user, Subscribe(0))
  process.send(engine, NewSubReddit)
  process.send(receiver, MakePost(0, -1, "First Post!", receiver))
  process.send(user, MakePost(0, 0, "Nice post.", user))
  process.send(user, RequestFeed(user))
}

fn get_zipf(i: Float, u: Float) {
  case u <. 0.0 {
    True -> i -. 1.0
    False -> {
      get_zipf(i +. 1.0, u -. 1.0 /. i)
    }
  }
}

// Simulating a large-scale Reddit community.
fn simulation(num_users: Int, n_subreddits: Int) {
  let engine = start_reddit_engine()
  let users = register_users(num_users, engine, [])
  register_subreddits(engine, n_subreddits)
  // denominator in Zipf distribution.
  let hn =
    list.fold(list.range(1, n_subreddits), 0.0, fn(ac, k) {
      ac +. 1.0 /. int.to_float(k)
    })
  user_subscribe_subreddits(users, n_subreddits, hn, n_subreddits, 10.0)
  // Initialize pairs list with (subreddit_id, max_post_id) for each subreddit.
  // max_post_id starts at -1 to indicate no posts yet for that subreddit.
  let pairs = list.map(list.range(0, n_subreddits - 1), fn(i) { #(i, -1) })
  // Periodically send messages to all users
  process.spawn(fn() { loop(users, pairs) })
}

fn loop(users: List(process.Subject(UserMsg)), pairs: List(#(Int, Int))) -> Nil {
  io.println("** Periodically: Users taking random actions.")
  let pairs = generate_msg(users, pairs)
  // Users take random actions every 2 seconds
  process.sleep(200)
  io.println("")
  loop(users, pairs)
}

fn generate_msg(
  users: List(process.Subject(UserMsg)),
  subreddits: List(#(Int, Int)),
) -> List(#(Int, Int)) {
  case users {
    [user, ..rest] -> {
      let partner = random_element(users)
      let action = int.random(10)
      // Choose a random subreddit from the tracked subreddits list
      case list.length(subreddits) {
        0 -> {
          // No subreddits tracked; nothing to do for subreddit-related actions
          generate_msg(rest, subreddits)
        }
        _ -> {
          // Zipf distribution for which subreddit to interact with
          let hn =
            list.fold(list.range(1, list.length(subreddits)), 0.0, fn(ac, k) {
              ac +. 1.0 /. int.to_float(k)
            })
          let sr_id = float.round(get_zipf(1.0, float.random() *. hn)) - 1
          let assert Ok(max_post_id) = list.key_find(subreddits, sr_id)
          // Determine a valid parent/post id when needed based on max_post_id
          // 70% Upvote    30% Downvote 
          let vote = int.random(10) > 2
          // Random Action:
          // 10% SendDM  10% Subscribe  10% Make a new post  20% Comment(or do nothing) 10% Vote(or do nothing) 40% Request feed
          let subreddits = case action {
            0 -> {
              process.send(user, SendDM(partner, "Hi there."))
              subreddits
            }
            // New top-level post: increment tracked max_post_id for this subreddit
            2 -> {
              process.send(user, MakePost(sr_id, -1, "Hello Reddit!", user))
              list.map(subreddits, fn(item) {
                let #(id, max_id) = item
                case id == sr_id {
                  True -> #(id, max_id + 1)
                  False -> #(id, max_id)
                }
              })
            }
            // Reply to an existing post (if any). If none exist, treat as a new post.
            3 -> {
              io.println("Trying to reply to: " <> int.to_string(max_post_id))
              case max_post_id {
                -1 -> {
                  subreddits
                }
                _ -> {
                  let parent = int.random(max_post_id)
                  io.println("Making reply: " <> int.to_string(parent))
                  // A reply creates a new post (child) so increment max_post_id locally
                  process.send(
                    user,
                    MakePost(sr_id, parent, "Nice post!", user),
                  )
                  list.map(subreddits, fn(item) {
                    let #(id, max_id) = item
                    case id == sr_id {
                      True -> #(id, max_id + 1)
                      False -> #(id, max_id)
                    }
                  })
                }
              }
            }
            // Another reply variant
            4 -> {
              case max_post_id {
                -1 -> {
                  subreddits
                }
                _ -> {
                  let parent = int.random(max_post_id)
                  process.send(
                    user,
                    MakePost(sr_id, parent, "I disagree.", user),
                  )
                  list.map(subreddits, fn(item) {
                    let #(id, max_id) = item
                    case id == sr_id {
                      True -> #(id, max_id + 1)
                      False -> #(id, max_id)
                    }
                  })
                }
              }
            }
            // Vote: only if there are posts in the subreddit
            5 -> {
              case max_post_id {
                -1 -> Nil
                _ -> {
                  let voted_post = int.random(max_post_id)
                  process.send(user, Vote(sr_id, voted_post, vote))
                }
              }
              subreddits
            }
            // do nothing (inactivity)
            9 -> subreddits
            _ -> {
              process.send(user, RequestFeed(user))
              subreddits
            }
          }
          generate_msg(rest, subreddits)
        }
      }
    }
    [] -> subreddits
  }
}

pub fn main() {
  let args = argv.load().arguments
  case args {
    [num_users] -> {
      io.println("*** Start Simulation: A simple demo with 3 users. ***")
      io.println("")
      run_demo(3)
      process.sleep(1000)
      io.println("")

      io.println("*** Start Simulation: A large-scale Reddit community. ***")
      io.println("")
      let assert Ok(num_users) = int.parse(num_users)
      simulation(num_users, 100)
      process.sleep(1000)
    }
    _ -> io.println("Please provide arguments: num_users")
  }
  process.sleep(1000)
}
