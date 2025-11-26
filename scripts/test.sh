# 1) Create subreddit
echo "1) Create subreddit"
HTTP_CODE=$(curl -s -o /tmp/test_create_sub.out -w "%{http_code}" -d '{"name":"Integration test"}' \
-X POST http://127.0.0.1:8080/create_subreddit)
cat /tmp/test_create_sub.out
if [ "$HTTP_CODE" != "201" ]; then
  echo "Create subreddit failed (code $HTTP_CODE)"
  #exit 1
fi


# 1) Create users
echo "2) Create user"
HTTP_CODE=$(curl -s -o /tmp/test_create_sub.out -w "%{http_code}" -d '{"user_id":0}' \
-X POST http://127.0.0.1:8080/create_user)
cat /tmp/test_create_sub.out
if [ "$HTTP_CODE" != "201" ]; then
  echo "Create subreddit failed (code $HTTP_CODE)"
  #exit 1
fi

HTTP_CODE=$(curl -s -o /tmp/test_create_sub.out -w "%{http_code}" -d '{"user_id":1}' \
-X POST http://127.0.0.1:8080/create_user)
cat /tmp/test_create_sub.out
if [ "$HTTP_CODE" != "201" ]; then
  echo "Create subreddit failed (code $HTTP_CODE)"
  #exit 1
fi

# 3) Create post
echo "3) Create post"
HTTP_CODE=$(curl -s -o /tmp/test_create_post.out -w "%{http_code}" -X POST -H "Content-Type: application/json" \
  -d '{"subreddit":0,"parent":-1,"poster":1,"text":"Integration test post"}' \
  http://127.0.0.1:8080/create_post)
cat /tmp/test_create_post.out
if [ "$HTTP_CODE" != "202" ]; then
  echo "Create post failed (code $HTTP_CODE)"
  #exit 1
fi

# 4) Vote
echo "4) Vote"
HTTP_CODE=$(curl -s -o /tmp/test_vote.out -w "%{http_code}" -X POST -H "Content-Type: application/json" \
  -d '{"subreddit":0,"post_id":0,"up":true}' \
  http://127.0.0.1:8080/vote)
cat /tmp/test_vote.out
if [ "$HTTP_CODE" != "200" ]; then
  echo "Vote failed (code $HTTP_CODE)"
  #exit 1
fi

# 5) Feed sync
echo "5) Feed sync"
HTTP_CODE=$(curl -s -o /tmp/test_feed.out -w "%{http_code}" -X POST -H "Content-Type: application/json" \
  -d '{"subs_csv":"0","k":10}' \
  http://127.0.0.1:8080/feed_sync)

echo "HTTP code: $HTTP_CODE"
echo "Body:"
cat /tmp/test_feed.out
if [ "$HTTP_CODE" != "200" ]; then
  echo "Feed sync failed (code $HTTP_CODE)"
  #exit 1
fi

echo "Integration tests passed."
#exit 0
