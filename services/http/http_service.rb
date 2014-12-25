$:.push(File.join(ENV['HENZELL_ROOT'], 'src'))

SERVICE_PORT = 29880

require 'bundler/setup'
require 'sinatra'

require 'cmd/executor'
require 'services/request_throttle'
require 'services/learndb'
require 'json'

set :port, SERVICE_PORT

get '/ldb' do
  content_type :json
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
      return {err: e.to_s}.to_json
    rescue
      status 500
      STDERR.puts($!.to_s + ": " + $!.backtrace.join("\n"))
      return {err: $!.to_s}.to_json
    end
  }
end
