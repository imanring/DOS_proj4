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
        <> " users",
      )
      list.reverse(users)
    }
    _ -> {
      let user = start_user(num - 1, engine)
      register_users(num - 1, engine, list.append(users, [user]))
    }
  }
}

pub fn random_action(
  user: process.Subject(UserMsg),
  receiver: process.Subject(UserMsg),
) {
  // generate a random action
  let seed = int.random(5)
  // A simple template, to be completed
  case seed {
    0 -> process.send(user, RequestFeed(user))
    1 -> process.send(user, SendDM(receiver, "Hi there!"))
    // For simplicity the sr_id and post_id are all set to 0 here
    2 -> process.send(user, MakePost(0, -1, "This is a Post.", user))
    3 -> process.send(user, Vote(0, 0, True))
    _ -> process.send(user, Subscribe(0))
  }
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
  echo gen_zipf(10, 5)
  let args = argv.load().arguments
  case args {
    [num_users] -> {
      let assert Ok(num_users) = int.parse(num_users)
      let engine = start_reddit_engine()
      let users = register_users(num_users, engine, [])
      let assert Ok(user) = list.first(users)
      let assert Ok(receiver) = list.last(users)
      process.send(user, SendDM(receiver, "Hi there!"))
      process.send(user, Subscribe(0))
      process.send(engine, NewSubReddit)
      process.send(receiver, MakePost(0, -1, "First Post!", receiver))
      process.send(user, RequestFeed(user))
      process.sleep(1000)
    }
    _ -> io.println("Please provide arguments: num_users")
  }

  // let user1 = start_user(1, engine)
  // let user2 = start_user(2, engine)
  // process.send(user2, ReceiveDM(user1, "A test message"))
  // process.send(user1, UpdateKarma(10.0))
  process.sleep(1000)
}
