import argv
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/string

pub type DMThread {
  DMThread(
    receiver: process.Subject(UserMsg),
    sender: process.Subject(UserMsg),
    messages: String,
  )
}

// User
pub type UserState {
  UserState(
    self: Option(process.Subject(UserMsg)),
    id: Int,
    karma: Float,
    dms: List(DMThread),
    subscriptions: List(Int),
    engine: process.Subject(EngineMsg),
  )
}

pub type UserMsg {
  ShutDown
  Initialize(self: process.Subject(UserMsg))
  GetFeed
  ReceiveFeed(posts: List(Post))
  SendDM(receiver: process.Subject(UserMsg), dm: String)
  ReceiveDM(sender: process.Subject(UserMsg), dm: String)
  MakePost(subreddit: Int, parent: Int, text: String)
  Vote(subreddit: Int, post_id: Int, up_vote: Bool)
  UpdateKarma(delta: Float)
  Subscribe(subreddit: Int)
}

fn print_feed(posts: List(Post)) {
  case posts {
    [] -> {
      io.println("")
    }
    [post, ..rest] -> {
      io.println(
        "Post id: " <> int.to_string(post.id) <> " text: " <> post.text,
      )
      print_feed(rest)
    }
  }
}

fn user_messages(state: UserState, msg: UserMsg) {
  case msg {
    ShutDown -> actor.stop()

    Initialize(self) -> {
      actor.continue(UserState(..state, self: Some(self)))
    }

    GetFeed -> {
      process.send(state.engine, SendFeed(state.subscriptions))
      actor.continue(state)
    }

    ReceiveFeed(posts) -> {
      let sbs = list.map(state.subscriptions, int.to_string)
      let joined = string.join(sbs, ", ")
      io.println(
        "User "
        <> int.to_string(state.id)
        <> " receiving feed from the engine. Its subcriptions are Subreddit: "
        <> joined,
      )

      print_feed(posts)
      actor.continue(state)
    }

    SendDM(receiver, dm) -> {
      case state.self {
        Some(sender) -> {
          let new_dm_thread = DMThread(receiver, sender, dm)
          let new_dms = list.append(state.dms, [new_dm_thread])

          io.println(
            "User "
            <> int.to_string(state.id)
            <> " is sending a message to a user.",
          )
          process.send(receiver, ReceiveDM(sender, dm))
          actor.continue(UserState(..state, dms: new_dms))
        }
        _ -> {
          io.println(
            "Fatal: Wrong initialization for user "
            <> int.to_string(state.id)
            <> ".",
          )
          actor.continue(state)
        }
      }
    }

    ReceiveDM(sender, dm) -> {
      case state.self {
        Some(receiver) -> {
          let new_dm_thread = DMThread(receiver, sender, dm)
          let new_dms = list.append(state.dms, [new_dm_thread])
          io.println(
            "User "
            <> int.to_string(state.id)
            <> " receives message '"
            <> dm
            <> "'.",
          )
          actor.continue(UserState(..state, dms: new_dms))
        }
        _ -> {
          io.println(
            "Fatal: Wrong initialization for user "
            <> int.to_string(state.id)
            <> ".",
          )
          actor.continue(state)
        }
      }
    }

    MakePost(subreddit, parent, text) -> {
      process.send(state.engine, NewPost(subreddit, parent, text))
      actor.continue(state)
    }

    Vote(subreddit, post, up_vote) -> {
      process.send(state.engine, CastVote(subreddit, post, up_vote))
      actor.continue(state)
    }

    UpdateKarma(delta) -> {
      let new_karma = state.karma +. delta
      io.println(
        "User "
        <> int.to_string(state.id)
        <> "'s Karma updated: "
        <> float.to_string(state.karma)
        <> " -> "
        <> float.to_string(new_karma),
      )
      actor.continue(UserState(..state, karma: new_karma))
    }

    Subscribe(subreddit) -> {
      let new_subs = list.append(state.subscriptions, [subreddit])
      io.println(
        "User "
        <> int.to_string(state.id)
        <> " has subscribed subReddit "
        <> int.to_string(subreddit)
        <> ".",
      )
      actor.continue(UserState(..state, subscriptions: new_subs))
    }
  }
}

fn start_user(
  id: Int,
  engine: process.Subject(EngineMsg),
) -> process.Subject(UserMsg) {
  let init = UserState(None, id, 0.0, [], [], engine)

  let builder =
    actor.new(init)
    |> actor.on_message(user_messages)

  let assert Ok(started) = actor.start(builder)
  actor.send(started.data, Initialize(started.data))
  started.data
}

pub type SubReddit {
  SubReddit(id: Int, posts: List(Post))
}

pub type Post {
  Post(
    id: Int,
    text: String,
    children: List(Post),
    up_votes: Int,
    down_votes: Int,
    poster: process.Subject(UserMsg),
  )
}

// Engine Placeholder
pub type EngineState {
  EngineState(List(SubReddit))
}

fn start_engine(subreddits: List(SubReddit)) -> process.Subject(EngineMsg) {
  let init = EngineState(subreddits)

  let builder = actor.new(init)

  let assert Ok(started) = actor.start(builder)
  started.data
}

pub type EngineMsg {
  NewPost(subreddit: Int, parent: Int, text: String)
  CreateSubreddit
  CastVote(subreddit: Int, post: Int, up_vote: Bool)
  SendFeed(subscriptions: List(Int))
}

// Simulator
fn register_users(
  num: Int,
  engine: process.Subject(EngineMsg),
  users: List(process.Subject(UserMsg)),
) {
  // let l = list.length(users)
  // case l - 1 > 0 {
  //   False -> io.println("Registering users. " <> int.to_string(list.length(users)) <> " user exists now.")
  //   True ->  io.println("Registering users. " <> int.to_string(list.length(users)) <> " users exist now.")
  // }
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

fn random_action(
  user: process.Subject(UserMsg),
  receiver: process.Subject(UserMsg),
) {
  // generate a random action
  let seed = int.random(5)
  // A simple template, to be completed
  case seed {
    0 -> process.send(user, GetFeed)
    1 -> process.send(user, SendDM(receiver, "Hi there!"))
    // For simplicity the sr_id and post_id are all set to 0 here
    2 -> process.send(user, MakePost(0, -1, "This is a Post."))
    3 -> process.send(user, Vote(0, 0, True))
    _ -> process.send(user, Subscribe(0))
  }
}

// Main process
pub fn main() {
  let args = argv.load().arguments
  case args {
    [num_users] -> {
      let assert Ok(num_users) = int.parse(num_users)
      let engine = start_engine([])
      let users = register_users(num_users, engine, [])
      let assert Ok(user) = list.first(users)
      let assert Ok(receiver) = list.last(users)
      process.send(user, SendDM(receiver, "Hi there!"))
      process.send(user, Subscribe(0))
      process.send(user, ReceiveFeed([]))
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
