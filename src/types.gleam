import gleam/erlang/process

pub type UserMsg {
  ShutDown
  Initialize(self: process.Subject(UserMsg))
  RequestFeed(reply_to: process.Subject(UserMsg))
  ReceiveFeed(posts: List(List(Post)))
  SendDM(receiver: process.Subject(UserMsg), dm: String)
  ReceiveDM(sender: process.Subject(UserMsg), dm: String)
  MakePost(
    subreddit: Int,
    parent: Int,
    text: String,
    poster: process.Subject(UserMsg),
  )
  Vote(subreddit: Int, post_id: Int, up_vote: Bool)
  UpdateKarma(delta: Float)
  Subscribe(subreddit: Int)
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
    karma: Int,
    // up_votes - down_votes + children karma + # of children
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
  GetFeed(subscriptions: List(Int), k: Int, reply_to: process.Subject(UserMsg))
  GetStats
}

pub type RedditEngineState {
  RedditEngineState(
    subreddits: List(SubReddit),
    max_subreddit_id: Int,
    total_msg: Int,
  )
}
