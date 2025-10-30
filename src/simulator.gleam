import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import reddit_engine.{start_reddit_engine}
import types.{
  type UserMsg, CastVote, GetFeed, MakePost, NewPost, NewSubReddit, ReceiveFeed,
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
        ReceiveFeed(_sub_reddits) -> {
          io.println("Received feed!")
          actor.continue(state)
        }
      }
    })
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
  process.send(reddit_engine, GetFeed([1], 2, user1))
  process.sleep(1000)
}
