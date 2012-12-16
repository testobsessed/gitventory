require 'sinatra'
require 'net/https'
require 'open-uri'
require 'github_api'
require 'json'
require 'haml'
require 'date'

Dir["helpers/*.rb"].each {|file| require file }

# note that the secret key for this app is set as an environment variable
# if the app stops working, double check that SECRET_KEY is set and is
# correct according to the app settings in github.


class GitventoryApp < Sinatra::Base
  set :secret_key, ENV['SECRET_KEY']
  attr :github
  
  before do
    @github = Github.new :client_id => "943a62469e4b2721bebe", :client_secret => settings.secret_key
  end

  helpers do
    include ViewHelpers
  end
  
  get '/hi' do
    @page_title = "Howdy!"
    "Hello World! Your secret is #{settings.secret_key}"
  end

  get '/login' do
    redirect @github.authorize_url
  end

  get '/limit' do
    @page_title = "About Rate Limits"
    url_limit = open("https://api.github.com/rate_limit", :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE).readline #JSON.parse(open("https://api.github.com/rate_limit").read)
    "With the github object #{@github.ratelimit_remaining}, with Github #{Github.ratelimit_remaining} and just from the URL #{url_limit}"
  end

  get '/say' do
    @things = ["whiskers on kittens", "brown paper packages", "yaks"]
    @message = "The secret message is: #{params}"
    haml :say
  end

  get '/inventory/:account' do
    @account = params[:account]
    @page_title = "Repos for #{@account}"
    @repos = Github.repos.list(:user => @account, :per_page => 100)
    haml :inventory
  end

  get '/' do
    if (params.count == 1 && params["code"])
      authorization_code = params[:code]
      token = @github.get_token( authorization_code )
      @github = Github.new(:oauth_token => token.token)
      "Auth code was #{authorization_code}. Token was #{token.token}. Rate limit is now #{@github.ratelimit}. Github can see repos for cloudfoundry?"
    else
      "GARDEN SQUIRRELS! " + params.to_s
    end
  end
end

