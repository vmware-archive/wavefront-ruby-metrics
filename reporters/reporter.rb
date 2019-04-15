module Reporters
  class Reporter
    def initialize(registry=nil, reporting_interval=5)
      @registry = registry
      @reporting_interval = reporting_interval
      @lock = Mutex.new
      @closed = true
      @task = nil
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
        @task.join
        @task = nil
      end
    end

    # Flush the data into scheduled interval.
    def schedule_task
      while !@closed do
        sleep(@reporting_interval)
        begin
        report_now
        rescue Exception => e
            puts "Reporter Exception: #{e.inspect}"
          end
      end
      report_now
    end

    # This will report the data to the specific reporter. All reporter needs to implement this.
    def report_now
      raise NotImplementedError, 'report_now has not been implemented.'
    end
  end
end