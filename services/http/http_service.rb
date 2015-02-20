$:.push(File.join(ENV['HENZELL_ROOT'], 'src'))

SERVICE_PORT = 29880

require 'bundler/setup'
require 'sinatra'

require 'cmd/executor'
require 'services/request_throttle'
require 'services/learndb'
require 'services/listgame'
require 'json'

CONCURRENT_LG_MAX = 5

set :port, SERVICE_PORT

def reporting_errors
  yield
rescue
  status 500
  STDERR.puts($!.to_s + ": " + $!.backtrace.join("\n"))
  { err: $!.to_s }.to_json
end

get '/game' do
  Services::RequestThrottle.throttle(CONCURRENT_LG_MAX, self) {
    reporting_errors {
      Services::Listgame::Query.new(CTX_LOG, params).result
    }
  }
end

get '/milestone' do
  Services::RequestThrottle.throttle(CONCURRENT_LG_MAX, self) {
    reporting_errors {
      Services::Listgame::Query.new(CTX_STONE, params).result
    }
  }
end

get '/ldb' do
  content_type :json, 'charset' => 'utf-8'
  search = params[:search].to_s
  lookup = params[:term].to_s
  unless search != '' || lookup != ''
    status 400
    return {err: "Bad request: must specify query with ?term=X or ?search=X"}.to_json
  end

  Services::RequestThrottle.throttle(10, self) {
    begin
      if !search.empty?
        Services::LearnDB::Search.new(search).result_json.to_json
      else
        Services::LearnDB::Lookup.new(lookup).result_json.to_json
      end
    rescue Services::LearnDB::NotFound => e
      status 404
      body({err: e.to_s}.to_json)
    rescue
      status 500
      STDERR.puts($!.to_s + ": " + $!.backtrace.join("\n"))
      body({err: $!.to_s}.to_json)
    end
  }
end

error Sinatra::NotFound do
  status 404
  'Not Found'
end
