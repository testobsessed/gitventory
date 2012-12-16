require 'sinatra'

get '/hi' do
  "Hello World!"
end

get '/login' do
  redirect "https://github.com/login/oauth/authorize?client_id=943a62469e4b2721bebe&redirect_uri=http://gitventory.cloudfoundry.com/authed"
end

get '/auth' do
  "Were you redirected here?"
end