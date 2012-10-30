require 'rack/timeout'
use Rack::Timeout
Rack::Timeout.timeout = 45

require 'services/http_service'
run Sinatra::Application