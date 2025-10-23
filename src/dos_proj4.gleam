import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor

pub type DMThread {
  DMThread(partner: process.Subject(UserMsg), messages: String)
}

pub type UserState {
  UserState(
    id: Int,
    karma: Float,
    dms: List(DMThread),
    subscriptions: List(Int),
    engine: process.Subject(EngineMsg),
  )
}

pub type UserMsg {
  ShutDown
  GetFeed
  SendDM(
    self: process.Subject(UserMsg),
    receiver: process.Subject(UserMsg),
    dm: String,
  )
  ReceiveDM(sender: process.Subject(UserMsg), dm: String)
  MakePost(subreddit: Int, parent: Int, text: String)
  Vote(subreddit: Int, post_id: Int, up_vote: Bool)
  UpdateKarma(delta: Float)
  Subscribe(subreddit: Int)
}

fn handle_messages(state: UserState, msg: UserMsg) {
  case msg {
    ShutDown -> actor.stop()

    GetFeed -> {
      process.send(state.engine, SendFeed(state.subscriptions))
      actor.continue(state)
    }

    // Somehow redendunt. Might be removed later.
    SendDM(sender, receiver, dm) -> {
      process.send(receiver, ReceiveDM(sender, dm))
      actor.continue(state)
    }

    ReceiveDM(sender, dm) -> {
      let new_dm_thread = DMThread(sender, dm)
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

    MakePost(subreddit, parent, text) -> {
      process.send(state.engine, PushPost(subreddit, parent, text))
      actor.continue(state)
    }

    Vote(subreddit, post, up_vote) -> {
      process.send(state.engine, PushVote(subreddit, post, up_vote))
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
      actor.continue(UserState(..state, subscriptions: new_subs))
    }
  }
}

fn start_user(
  id: Int,
  engine: process.Subject(EngineMsg),
) -> process.Subject(UserMsg) {
  let init = UserState(id, 0.0, [], [], engine)

  let builder =
    actor.new(init)
    |> actor.on_message(handle_messages)

  let assert Ok(started) = actor.start(builder)
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
  PushPost(subreddit: Int, parent: Int, text: String)
  CreateSubreddit
  PushVote(subreddit: Int, post: Int, up_vote: Bool)
  SendFeed(subscriptions: List(Int))
}

// Add something

pub fn main() {
  let engine = start_engine([])
  let user1 = start_user(1, engine)
  let user2 = start_user(2, engine)
  process.send(user2, ReceiveDM(user1, "A test message"))
  process.send(user1, UpdateKarma(10.0))
  process.sleep(1000)
}
