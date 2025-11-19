import argv
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option
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

fn random_element(users: List(a)) -> a {
  let len = list.length(users)
  let index = int.random(len - 1)
  let remaining = list.drop(users, index)
  let assert Ok(user) = list.first(remaining)
  user
}

fn initialize_subreddits(engine, users, sr_usrs) {
  let len = list.length(sr_usrs)
  register_subreddits(engine, len)
  subscribe_subreddits(engine, users, sr_usrs, 0)
}

fn register_subreddits(engine, num: Int) {
  case num > 0 {
    True -> process.send(engine, NewSubReddit)
    False -> register_subreddits(engine, num - 1)
  }
}

fn subscribe_subreddits(engine, users, sr_usrs, index) {
  case sr_usrs {
    [num, ..rest] -> {
      user_subscribe_subreddits(users, num, index)
      subscribe_subreddits(engine, users, rest, index + 1)
    }
    [] -> Nil
  }
}

fn user_subscribe_subreddits(users, num, sr_id) {
  case num > 0 {
    True -> {
      case users {
        [user, ..rest] -> {
          process.send(user, Subscribe(sr_id))
          user_subscribe_subreddits(rest, num - 1, sr_id)
        }
        [] -> io.println("Fatal: Empty user list!")
      }
    }
    False -> Nil
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

// Simulating a large-scale Reddit community.
fn simulation(num_users: Int) {
  let engine = start_reddit_engine()
  let users = register_users(num_users, engine, [])
  let sr_usrs = gen_zipf(1000, 100)
  initialize_subreddits(engine, users, sr_usrs)
  // Periodically send messages to all users
  process.spawn(fn() { loop(users) })
}

fn loop(users: List(process.Subject(UserMsg))) -> Nil {
  io.println("** Periodically: Users taking random actions.")
  let pairs = generate_msg(users, [])
  list.each(pairs, fn(pair) {
    let #(user, msg) = pair
    process.send(user, msg)
  })
  // Users take random actions every 2 seconds
  process.sleep(2000)
  io.println("")
  loop(users)
}

fn generate_msg(
  users: List(process.Subject(UserMsg)),
  pairs: List(#(process.Subject(UserMsg), UserMsg)),
) -> List(#(process.Subject(UserMsg), UserMsg)) {
  case users {
    [user, ..rest] -> {
      let partner = random_element(users)
      let action = int.random(10)
      let sr_id = int.random(100)
      // For simplicity, choose a random post_id regardless of existence (if post doesn't exist, it will do nothing) 
      let post_id = int.random(1000)
      // 70% Upvote    30% Downvote 
      let vote = int.random(10) > 2
      // Random Action:
      // 10% SendDM  10% Subscribe  10% Make a new post  20% Comment(or do nothing) 10% Vote(or do nothing) 40% Request feed
      let pairs = case action {
        0 ->
          list.append(pairs, [
            #(user, SendDM(partner, "Hi there.")),
          ])
        1 ->
          list.append(pairs, [
            #(user, Subscribe(sr_id)),
          ])
        2 ->
          list.append(pairs, [
            #(user, MakePost(sr_id, -1, "Hello Reddit!", user)),
          ])
        3 ->
          list.append(pairs, [
            #(user, MakePost(sr_id, post_id, "Nice post!", user)),
          ])
        4 ->
          list.append(pairs, [
            #(user, MakePost(sr_id, post_id, "I disagree.", user)),
          ])
        5 ->
          list.append(pairs, [
            #(user, Vote(post_id, sr_id, vote)),
          ])
        _ ->
          list.append(pairs, [
            #(user, RequestFeed(user)),
          ])
      }
      generate_msg(rest, pairs)
    }
    [] -> pairs
  }
}
// pub fn main() {
//   let args = argv.load().arguments
//   case args {
//     [num_users] -> {
//       io.println("*** Start Simulation: A simple demo with 3 users. ***")
//       io.println("")
//       run_demo(3)
//       process.sleep(1000)
//       io.println("")

//       io.println("*** Start Simulation: A large-scale Reddit community. ***")
//       io.println("")
//       let assert Ok(num_users) = int.parse(num_users)
//       // simulation(num_users)
//       process.sleep(50_000)
//     }
//     _ -> io.println("Please provide arguments: num_users")
//   }
//   process.sleep(1000)
// }
