require 'sinatra'
require 'net/https'
require 'open-uri'
require 'github_api'
require 'json'
require 'haml'
require 'date'
require 'sinatra/async'
require 'thin'
require 'sinatra/partial'

Dir["helpers/*.rb"].each {|file| require file }

# note that the secret key for this app is set as an environment variable
# if the app stops working, double check that SECRET_KEY is set and is
# correct according to the app settings in github.


class GitventoryApp < Sinatra::Base
  set :secret_key, ENV['SECRET_KEY']
  attr :github
  attr :records
  
  register Sinatra::Async
  register Sinatra::Partial

  class MyStream
    include EventMachine::Deferrable

    def stream(object)
      @block.call object
    end

    def each(&block)
      @block = block
    end
  end
  
  before do
    @github = Github.new :client_id => "943a62469e4b2721bebe", :client_secret => settings.secret_key
  end

  helpers do
    include ViewHelpers
  end
  
  get '/hi' do
    @page_title = "Howdy!"
    @message = "Hello World! Your secret is #{settings.secret_key}"
    haml :hi
    #puts headers
  end

  get '/login' do
    redirect @github.authorize_url
  end

  get '/limit' do
    @page_title = "About Rate Limits"
    "Remaining calls #{@github.ratelimit_remaining}"
  end

  get '/say' do
    @things = ["whiskers on kittens", "brown paper packages", "yaks"]
    @message = "The secret message is: #{params}"
    haml :say
  end

  aget '/inventory/:account' do
    @records = []
    @account = params[:account]
    @page_title = "Repos for #{@account}"
    myout = MyStream.new
    body myout
    myout.stream(haml :inventory)
    myout.succeed
    out = MyStream.new
    out.callback { show_inventory(@records, out) }
    all_repos = Github.repos.list(:user => @account, :per_page => 100)
    @repo_count = all_repos.count
    out.stream "Gathering Data. Please be patient."
    # @out.stream('<table id="inventory" class="tablesorter">')
    # @out.stream('<thead><tr><th class="header"> Repo Name </th><th class="header"> Branch Name </th><th class="header"> Last Checkin </th></tr></thead>')
    # @out.stream('<tbody>')
    repo_counter = 0
    all_repos.each do |repo|
      EM.next_tick do
        puts "!!!!!At top of tick loop with current repo count #{repo_counter} and total #{all_repos.count}"
        branch_counter = 0
        all_branches = Github::Repos.new(:repo => repo["name"], :user => @account).branches(@account, repo["name"])
        all_branches.each do |branch|
          #puts "!!!!!At top of branch loop with current repo count #{repo_counter} and total #{all_repos.count}"
          timer = EM.add_periodic_timer(0.3) do
            out.cancel_timeout
            puts "Working on #{branch.name}"
            @repo_name = repo["name"]
            @branch_name = branch.name
            @commit_date = DateTime.parse(github.repos.commits.get(@account, repo["name"], branch.commit.sha).commit.committer["date"]).strftime("%m/%d/%Y (%T)")
            # puts "!!!!!!!!!!!!!  STREAM: #{@repo_name}, #{@branch_name}, #{@commit_date}"
            @records.push([@repo_name, @branch_name, @commit_date])
            out.stream "."
            branch_counter += 1
            if (branch_counter == all_branches.count)
              puts "!!!!!!!!!!!!DONE WITH BRANCHES FOR #{repo["name"]}. Currently have #{@records.count} records."
              repo_counter += 1
              timer.cancel
            end
            if (repo_counter == all_repos.count)
              puts "!!!!!!!!!!DONE WITH REPOS"
              timer.cancel
              out.succeed
            end        
          end
        end
      end
    end
    
    #   
    #   name = repo["name"]
    #   puts "!!!!!!!!!!!!!!!!!!!Getting branches"
    #   all_branches = Github::Repos.new(:repo => repo["name"], :user => @account).branches(@account, name)
    #   all_branches.each { |branch|
    #     branches[branch.name] = DateTime.parse(github.repos.commits.get(@account, name, branch.commit.sha).commit.committer["date"]).strftime("%m/%d/%Y (%T)")
    #   }
    #   @repos[name] = branches
    #}
    # repos = 
    # repos.branches do |branch|
    #   puts branch.name
    # end
    #haml :inventory
        
  end
  def show_inventory(records, out)
    puts "IN SHOW INVENTORY WITH #{records.count} records"
    #redirect to('/display')
    @records = records
    out.stream partial(:inventory_done)
  end
  
  get '/display' do
    puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!HERE"
    haml :inventory_done
  end
  
  
  
  aget '/foo' do
    @page_title = "Testing Async w/ Templates and Partials"
    haml :foo
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