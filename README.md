# dos_proj4

Reddit API is implemented

```
create_user {"user_id": 0}
create_user {"user_id": 1}
create_subreddit

create_post {"text": "Hello Reddit!", "subreddit": 0, "poster": 0}

create_post {"text": "Why are you posting this junk here?", "subreddit": 0, "poster": 1, "parent":0}

create_post {"text": "I believe the moon is flat. This is obvious. What do you think?", "subreddit": 0, "poster": 1}

vote {"up": false, "post_id": 2, "subreddit": 0}

feed_sync {"subs_csv": "0", "k": 5}

create_user {"user_id": 2}
create_subreddit

send_dm {"sender_id": 2, "receiver_id": 0, "message": "I created a new positive vibes only subreddit. That way we can avoid user1"}

create_post {"text": "This is my new subreddit about Distributed Operating Systems", "subreddit": 1, "poster": 2}


create_post {"text": "Only the peer to peer networks count.", "subreddit": 1, "poster": 2}


create_post {"text": "Thanks for creating this subreddit. I love distributed operating systems!", "subreddit": 1, "poster": 0, "parent": 0}

vote {"up": true, "subreddit": 1, "post_id": 0}


vote {"up": false, "subreddit": 1, "post_id": 0}

create_post {"text": "What a dumb topic why would anyone care about that?", "subreddit": 1, "parent": 2, "poster": 1}

feed_sync {"subs_csv":"0,1","k": 5}
```