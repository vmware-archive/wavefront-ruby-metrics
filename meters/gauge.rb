require 'concurrent'
require_relative 'metric'

module Measurement
  class Gauge < Metric
    # @param name [string] Metric name
    # @param point_tags [Hash] Point tags for counter
    # @param initial_value [Integer] Initial value for counter
    def initialize(name, point_tags, initial_value = 0)
      super(name, point_tags)
      @value = Concurrent::AtomicReference.new(initial_value.to_f)
    end

    # Return current gauge value
    def value
      @value.get
    end

    # Set the current gauge value
    def value=(val)
      @value.set(val.to_f)
    end

    alias set value=
  end
end
