import gleam/erlang/process
import gleam/io
import gleam/list

pub type UserMsg {
  MakePost(Int, Int, String)
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
  )
}

pub type SubReddit {
  SubReddit(id: Int, name: String, posts: List(Post))
}

pub type RedditMsg {
  NewPost(Int, Int, String)
  NewSubReddit
  CastVote(subreddit_id: Int, post_id: Int, upvote: Bool)
  // True for upvote, False for downvote
  GetFeed(subscriptions: List(Int))
}

pub fn main() -> Nil {
  io.println("Hello from dos_proj4!")
}
