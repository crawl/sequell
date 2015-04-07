require 'thread'

module Services
  class Debounce
    def initialize(debounce_time)
      @mutex = Mutex.new
      @have_action = ConditionVariable.new
      @debounce_time = debounce_time
      @target_time = nil
      @debounce_thread = nil
    end

    def debounce(&action)
      @mutex.synchronize {
        @action = action
        @target_time = now_epoch_millis + @debounce_time
        if !@debounce_thread
          @debounce_thread = Thread.new {
            debounce_work
          }
        end
        @have_action.signal
      }
    end

  private

    def now_epoch_millis
      (Time.now.to_f * 1000).to_i
    end

    def debounce_work
      while true
        @mutex.synchronize {
          @have_action.wait(@mutex) unless @action
        }

        1 while maybe_sleep(sleep_interval)

        action = nil
        @mutex.synchronize {
          action = @action
          @action = nil
        }
        begin
          action.call if action
        rescue
          STDERR.puts "#$!"
          STDERR.puts("\t" + $!.backtrace.join("\n\t"))
        end
      end
    end

    def maybe_sleep(interval)
      sleep(interval) if interval > 0
      interval > 0
    end

    def sleep_interval
      @mutex.synchronize {
        interval = @target_time - now_epoch_millis
        if interval <= 0
          0
        else
          interval / 1000.0
        end
      }
    end
  end

  class RequestThrottle
    attr_reader :max_concurrent

    def initialize(max_concurrent)
      @mutex = Mutex.new
      @concurrent = 0
      @max_concurrent = max_concurrent
    end

    def throttle(context)
      @mutex.synchronize {
        @concurrent += 1
        if @concurrent > max_concurrent
          context.status 503
          context.body "Request temporarily refused, too many concurrent requests"
          return
        end
      }
      yield
    ensure
      @mutex.synchronize {
        @concurrent -= 1 if @concurrent > 0
      }
    end
  end
end
