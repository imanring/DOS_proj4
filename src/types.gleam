import gleam/erlang/process

pub type UserMsg {
  MakePost(Int, Int, String)
  ReceiveFeed(sub_reddits: List(List(Post)))
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
}

pub type RedditEngineState {
  RedditEngineState(subreddits: List(SubReddit), max_subreddit_id: Int)
}
