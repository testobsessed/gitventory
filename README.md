gitventory
==========

gitventory

All I wanted was a simple inventory of repos and branches and last commit dates for a given user account.

This has turned into the ultimate yak shaving experience.

I started with curl at the command line using the github API. But, of course, curl doesn't give you back information
in a human readable format.

So I write a teeny little ruby app that used open-uri to open the connections, and JSON.parse to interpret the results. This worked awesome...until I hit the rate limit of 60 queries.

The next thing I knew I'd turned my little app into a sinatra web app, registered it with github, and was shaving the oauth yak. Thanks to the github api gem, that yak only took about 6 hours. (It would have taken less had I ever done auth stuff before, I'm sure. But I'd managed to dodge the oauth and api yak successfully in the past.)

Then I thought that I wanted to sort the results, so I spent some time shaving the sortabletable jquery plugin yak.

Now I had a rate limit of 5000 requests and a sortable table to populate! I was in business!

Only it turns out that if you have more than a few repos, it takes too long to return all the records and the request times out.

So now I'm on the async yak with the partials yak thrown in to boot. 