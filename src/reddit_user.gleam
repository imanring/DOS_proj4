import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/string
import types.{
  type Post, type RedditMsg, type UserMsg, CastVote, GetFeed, Initialize,
  MakePost, NewPost, ReceiveDM, ReceiveFeed, RequestFeed, SendDM, ShutDown,
  Subscribe, UpdateKarma, Vote,
}

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
    engine: process.Subject(RedditMsg),
  )
}

// print subreddit feed (for testing)
fn print_feed(posts: List(Post), indent: String) -> Nil {
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
      let _ = print_feed(post.children, indent <> "  ")
      print_feed(rest, indent)
    }
  }
}

fn print_subreddits(subreddits: List(List(Post))) {
  case subreddits {
    [] -> Nil
    [head, ..tail] -> {
      print_feed(head, "")
      print_subreddits(tail)
    }
  }
}

fn user_messages(state: UserState, msg: UserMsg) {
  case msg {
    ShutDown -> actor.stop()

    Initialize(self) -> {
      actor.continue(UserState(..state, self: Some(self)))
    }

    RequestFeed(reply_to) -> {
      process.send(state.engine, GetFeed(state.subscriptions, 3, reply_to))
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
      print_subreddits(posts)
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

    MakePost(subreddit, parent, text, poster) -> {
      process.send(state.engine, NewPost(subreddit, parent, text, poster))
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
      //io.println(
      //  "User "
      //  <> int.to_string(state.id)
      //  <> " has subscribed subReddit "
      //  <> int.to_string(subreddit)
      //  <> ".",
      //)
      actor.continue(UserState(..state, subscriptions: new_subs))
    }
  }
}

pub fn start_user(
  id: Int,
  engine: process.Subject(RedditMsg),
) -> process.Subject(UserMsg) {
  let init = UserState(None, id, 0.0, [], [], engine)

  let builder =
    actor.new(init)
    |> actor.on_message(user_messages)

  let assert Ok(started) = actor.start(builder)
  actor.send(started.data, Initialize(started.data))
  started.data
}
