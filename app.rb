require 'sinatra'
# require 'net/https'
require 'httparty'
require 'open-uri'
require 'github_api'
require 'json'
require 'haml'
require 'date'
require 'sinatra/async'
require 'thin'
require 'sinatra/partial'
#require 'em-http'

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
  
  aget '/repos/:account' do
    account = params[:account]
    listurl = "https://api.github.com/users/#{account}/repos"
    
    records = []
    
    # myout = MyStream.new
    # body myout
    # myout.stream(haml :inventory)
    # myout.succeed
    out = MyStream.new
    body out
    out.stream erb(:inventory_head)
    # out.stream('<table id="inventory" class="tablesorter">')
    # out.stream('<thead><tr><th class="header"> Repo Name </th><th class="header"> Branch Name </th><th class="header"> Last Checkin </th></tr></thead>')
    # out.stream('<tbody>')
    out.callback { out.stream erb(:inventory_foot) }
    all_repos = HTTParty::get(listurl)
    puts "Done with get. All repos has #{all_repos.count} records."
    EM.next_tick do
      timer = EM.add_periodic_timer(0.3) do
        repo_counter = 0
        all_repos.each do |repo|
          repo_counter += 1
          puts "Working on repo #{repo_counter} of #{all_repos.count}"
          repo = {
            :repo_name => repo["name"],
            :branch_name => "n/a",
            :commit_date => "n/a"
          }
          show_item(repo, out)
          # records.push([repo_name, branch_name, commit_date])
          if (repo_counter == all_repos.count)
            puts "!!!!!!!!!!DONE WITH REPOS"
            timer.cancel
            out.succeed
          end
        end
      end
    end
  end

  aget '/inventory/:account' do
    account = params[:account]
    @page_title = "Repos for #{account}"
    list_repos_url = "https://api.github.com/users/#{account}/repos"
    
    out = MyStream.new
    body out
    out.stream erb(:inventory_head)
    
    out.callback { out.stream erb(:inventory_foot) }
    all_repos = HTTParty::get(list_repos_url)
    
    repo_counter = 0
    all_repos.each do |repo|
      EM.next_tick do
        repo_name = repo["name"]
        list_branches_url = "https://api.github.com/repos/#{account}/#{repo_name}/branches"

        branch_counter = 0
        all_branches = HTTParty::get(list_branches_url)
        all_branches.each do |branch|
          #puts "!!!!!At top of branch loop with current repo count #{repo_counter} and total #{all_repos.count}"
          timer = EM.add_periodic_timer(0.3) do
            out.cancel_timeout
            puts "Working on #{branch['name']}"
            inventory_item = {
              :repo_name => repo["name"],
              :branch_name => branch["name"],
              :commit_date => "n/a"
            }
            show_item(inventory_item, out)
            # @commit_date = DateTime.parse(github.repos.commits.get(@account, repo["name"], branch.commit.sha).commit.committer["date"]).strftime("%m/%d/%Y (%T)")
            # puts "!!!!!!!!!!!!!  STREAM: #{@repo_name}, #{@branch_name}, #{@commit_date}"
            branch_counter += 1
            if (branch_counter == all_branches.count)
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
  
  def show_item(thing, out)
    puts "Showing #{thing.to_s}"
    @thing = thing
    out.stream erb(:item)
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