# dos_proj4

[![Package Version](https://img.shields.io/hexpm/v/dos_proj4)](https://hex.pm/packages/dos_proj4)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/dos_proj4/)

```sh
gleam run 3
```

```sh
*** Start Simulation: A simple demo with 3 users. ***

New user(s) registered. Now there are 3 users.
User 0 is sending a message to a user.
User 0 has subscribed subReddit 0.
User 2 receives message 'Hi there!'.
User 0 receiving feed from the engine. Its subcriptions are Subreddit: 0
Post ID: 0, Text: First Post!, Upvotes: 0, Downvotes: 0, Karma: 1
  Post ID: 1, Text: Nice post., Upvotes: 0, Downvotes: 0, Karma: 0
```

We can also simulate a large-scale Reddit community. The subreddits are initialized with a number of subscribers based on a Zipf distribution. Each user will take a random action (including subscribe a subReddit, Make a post or comment, vote, send direct messages, and request feed) every 2 seconds.

```sh
gleam run 50000
```
