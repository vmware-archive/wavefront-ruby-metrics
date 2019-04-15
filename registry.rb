# Registry class gathers the metric of the service.
# It stores all supported type of the metric e.g. Counters, Gauges and Histograms.
#
require 'concurrent'
require_relative 'meters/counter'
require_relative 'meters/gauge'
require_relative 'histogram/histogram'

module Registry
  class MetricsRegistry
    class DuplicateKeyError < StandardError; end

    def initialize
      @store = Concurrent::Map.new
    end

    # Add metric into registry
    #
    # @param metric [Metric] metric to add it can be of any type
    # @return metric object
    def add(metric)
      raise TypeError unless metric.respond_to? :name

      key = metric.name
      unless @store.put_if_absent(key, metric).nil?
        raise DuplicateKeyError, "Cannot add duplicate metric into registry: #{key}"
      end

      metric
    end

    # Remove the metric from registry
    #
    # @param name [String] name of the metric
    def del(name)
      @store.delete(name.to_sym)
    end

    # Add a new Counter metric to the registry
    #
    # @param name [String] metric name
    # @param point_tags [Hash] metric point tags
    # @param initial_value [Integer] metric value
    #
    # @return [Counter] the counter object
    def counter(name, point_tags, initial_value = 0)
      add(Meters::Counter.new(name, point_tags, initial_value))
    end

    # Add a new Counter metric to the registry
    #
    # @param name [String] metric name
    # @param point_tags [Hash] metric point tags
    # @param initial_value [Integer] metric value
    #
    # @return [Gauge] the gauge object
    def gauge(name, point_tags, initial_value = 0)
      'add a new Gauge metric to the registry'
      add(Meters::Gauge.new(name, point_tags, initial_value))
    end

    def distribution(name, point_tags, accuracy = Meters::Histogram::DEFAULT_ACCURACY,
                     granularity = Meters::Granularity::MINUTE, max_bins = Meters::Histogram::DEFAULT_MAX_BINS,
                      clock_func = nil)
      add(Meters::Histogram.new(name, point_tags, accuracy, granularity, max_bins, clock_func))
    end

    # Check if metric exists
    #
    # @param name [String] name of the metric
    # @return [Bool]
    def exist?(name)
      @store.key?(name.to_sym)
    end

    # Get the metric by its name
    #
    # @param name [String] Metric name
    # @return [Metric] the metric value
    def get(name)
      @store[name.to_sym]
    end

    # Get all the metrics in registry
    # @return list of metrics
    def metrics
      @store.values
    end
  end
end
