$:.push(File.join(ENV['HENZELL_ROOT'], 'src'))

SERVICE_PORT = 29880

require 'bundler/setup'
require 'sinatra'

require 'cmd/executor'
require 'services/throttle'
require 'services/learndb'
require 'services/listgame'
require 'services/crawl_build'
require 'json'

$LG_THROTTLE = Services::RequestThrottle.new(5)
$LDB_THROTTLE = Services::RequestThrottle.new(5)
$BUILD_DEBOUNCE = Services::Debounce.new(10000)

set :port, SERVICE_PORT

def reporting_errors
  yield
rescue
  status 500
  STDERR.puts($!.to_s + ": " + $!.backtrace.join("\n"))
  { err: $!.to_s }.to_json
end

before do
  headers "Access-Control-Allow-Origin" => "*"
end

post '/crawl-build/' do
  $BUILD_DEBOUNCE.debounce {
    Services::CrawlBuild.rebuild
  }
end

get '/game' do
  $LG_THROTTLE.throttle(self) {
    reporting_errors {
      Services::Listgame::Query.new(CTX_LOG, params).result
    }
  }
end

get '/milestone' do
  $LG_THROTTLE.throttle(self) {
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

  $LDB_THROTTLE.throttle(self) {
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
