# frozen_string_literal: true

require_relative '../registry'

module Reporters
  class Reporter
    @@global_registry = Registry::MetricsRegistry.new

    attr_reader :registry

    def initialize(registry = nil, reporting_interval_sec = 5, internal_reporter = nil)
      @registry = registry || @@global_registry
      @internal_reporter = internal_reporter
      @reporting_interval_sec = reporting_interval_sec

      @lock = Mutex.new
      start
    end

    # Start reporting
    def start
      @lock.synchronize do
        @timer&.stop(0.5)
        @timer = ::Wavefront::EarlyTickTimer.new(@reporting_interval_sec, false) { report_now }
      end
    end

    # Stop reporting
    def stop(timeout = 3)
      # flush all metrics at end
      @timer.stop(timeout)
      report_now
      @internal_reporter&.stop
    end

    # This will report the data to the specific reporter. All reporter needs to implement this.
    def report_now
      raise NotImplementedError, 'report_now has not been implemented.'
    end
  end
end
