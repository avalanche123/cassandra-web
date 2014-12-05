# encoding: utf-8

require 'logger'

require 'rubygems'
require 'bundler/setup'

require 'sinatra/base'
require 'rack/cors'
require 'rack/parser'
require 'cassandra'
require 'json'

$: << File.expand_path('../', __FILE__)

class App < Sinatra::Base
  configure do
    set :root, File.expand_path('../', __FILE__) + '/app'

    enable  :static
    disable :views
    disable :method_override
    disable :protection
  end

  use Rack::Cors do
    allow do
      origins /.*/
      resource '/*',
        :methods => [:get, :post, :put, :delete, :options],
        :expose  => ['Location'],
        :headers => :any
    end
  end

  use Rack::Parser, :content_types => {
    'application/json'  => JSON.method(:load)
  }

  get '/events/?' do
    status 200
    content_type 'text/event-stream'
    headers 'Connection' => 'keep-alive'

    stream(:keep_open) do |out|
      stream_events(out)
    end
  end

  get '/hosts/?' do
    status 200
    content_type 'application/json'

    json_dump(cluster.hosts)
  end

  get '/keyspaces/?' do
    status 200
    content_type 'application/json'

    json_dump(cluster.keyspaces)
  end

  get '/consistencies/' do
    status 200
    content_type 'application/json'

    json_dump(Cassandra::CONSISTENCIES)
  end

  post '/execute/?' do
    content_type 'application/json'

    statement = params['statement']
    statement.strip!
    statement.chomp!(";")

    options = {
      :consistency => :one,
      :trace => false
    }

    if params['options']
      options[:trace]       = !!params['options']['trace'] if params['options'].has_key?('trace')
      options[:consistency] = params['options']['consistency'].to_sym if params['options'].has_key?('consistency') && Cassandra::CONSISTENCIES.include?(params['options']['consistency'].to_sym)
    end

    defer(session.execute_async(statement, options))
  end

  get '*' do
    File.read(File.join(settings.public_folder, 'main.html'))
  end
end

require 'app/helpers/async'
require 'app/helpers/json'
require 'app/helpers/sse'

App.helpers  App::Helpers::Async
App.helpers  App::Helpers::JSON
App.helpers  App::Helpers::SSE
