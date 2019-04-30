require_relative '../registry'

module Reporters
  class Reporter
    @@global_registry = Registry::MetricsRegistry.new

    attr_reader :registry

    def initialize(registry = nil, reporting_interval_sec = 5)
      @registry = registry || @@global_registry
      @reporting_interval_sec = reporting_interval_sec
      @lock = Mutex.new
      @closed = true
      @task = nil
      start
    end

    # Start reporting
    def start
      @lock.synchronize do
        if @closed
          @closed = false
          @task = Thread.start {schedule_task}
        end
      end
    end

    # Stop reporting
    def stop
      # Flush all buffer before close the client.
      @lock.synchronize do
        @closed = true
        @task.kill.join
        @task = nil
        begin  
          report_now
        rescue Exception => e
          raise e
        end
      end
    end

    # Flush the data into scheduled interval.
    def schedule_task
      while !@closed do
        sleep(@reporting_interval_sec)
        begin
          Thread.handle_interrupt(RuntimeError => :never) do
            report_now
          end
        rescue Exception => e
            puts "Reporter Exception: #{e.inspect}"
        end
      end
    end

    # This will report the data to the specific reporter. All reporter needs to implement this.
    def report_now
      raise NotImplementedError, 'report_now has not been implemented.'
    end
  end
end