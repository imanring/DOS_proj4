import gleam/erlang/process
import gleam/io
import gleam/otp/actor

pub type DMThread {
  DMThread(partner: process.Subject(UserMsg), messages: List(#(Bool, String)))
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
  SendDM(receiver: process.Subject(UserMsg), dm: String)
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
      actor.continue(state)
    }

    SendDM(receiver, dm) -> {
      actor.continue(state)
    }

    ReceiveDM(receiver, dm) -> {
      actor.continue(state)
    }

    MakePost(subreddit, parent, text) -> {
      actor.continue(state)
    }

    Vote(subreddit, post, up_vote) -> {
      actor.continue(state)
    }

    UpdateKarma(delta) -> {
      actor.continue(state)
    }

    Subscribe(subreddit) -> {
      actor.continue(state)
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

pub type EngineMsg

// Add something

pub fn main() {
  let engine = start_engine([])
  let user = start_user(1, engine)
}
