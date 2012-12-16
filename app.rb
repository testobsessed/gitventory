require 'sinatra'
require 'net/https'
require 'open-uri'
require 'github_api'
require 'json'


# note that the secret key for this app is set as an environment variable
# if the app stops working, double check that SECRET_KEY is set and is
# correct according to the app settings in github.

set :secret_key, ENV['SECRET_KEY']
github = Github.new :client_id => "943a62469e4b2721bebe", :client_secret => settings.secret_key

get '/hi' do
  "Hello World! Your secret is #{settings.secret_key}"
end

get '/login' do
  redirect github.authorize_url
end

get '/limit' do
  url_limit = open("https://api.github.com/rate_limit", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE).readline #JSON.parse(open("https://api.github.com/rate_limit").read)
  "With the github object #{github.ratelimit_remaining}, with Github #{Github.ratelimit_remaining} and just from the URL #{url_limit}"
end

get '/say' do
  "It said #{params[:response]}"
end

get '/inventory/:account' do
  account = params[:account]
  repos = Github.repos.list(:user => account, :per_page => 100)
  "#{account} has #{repos.count} repos: #{repos.map { |repo| repo["name"] }.to_s}"
end

get '/' do
  if (params.count == 1 && params["code"])
    authorization_code = params[:code]
    token = github.get_token( authorization_code )
    github = Github.new(:oauth_token => token.token)
    "Auth code was #{authorization_code}. Token was #{token.token}. Rate limit is now #{github.ratelimit}. Github can see repos for cloudfoundry?"
  else
    "GARDEN SQUIRRELS! " + params.to_s
  end
end

