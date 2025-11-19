import gleeunit
import reddit_api

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn parse_subscriptions_test() {
  let parsed = reddit_api.parse_subscriptions("1,2,3")
  assert parsed == ["1", "2", "3"]
}
