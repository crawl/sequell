require 'thread'

module Services
  class RequestThrottle
    @@mutex = Mutex.new
    @@concurrent = 0

    def self.throttle(max_concurrent, context)
      @@mutex.synchronize {
        @@concurrent += 1
        if @@concurrent > max_concurrent
          context.status 503
          context.body "Request temporarily refused, too many concurrent requests"
          return
        end
      }
      yield
    ensure
      @@mutex.synchronize {
        @@concurrent -= 1 if @@concurrent > 0
      }
    end
  end
end
