# Registry class gathers the metric of the service.
# It stores all supported type of the metric e.g. Counters, Gauges and Histograms.
#
require 'concurrent'
require 'json'
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

      key = encode_key(metric.name, metric.point_tags)
      @store.compute_if_absent(key) { metric }
    end

    # Remove the metric from registry
    #
    # @param name [String] name of the metric
    def del(name, point_tags={})
      @store.delete(encode_key(name, point_tags))
    end

    # Add a new Counter metric to the registry
    #
    # @param name [String] metric name
    # @param point_tags [Hash] metric point tags
    # @param initial_value [Integer] metric value
    #
    # @return [Counter] the counter object
    def counter(name, point_tags={}, initial_value = 0)
      add(Measurement::Counter.new(name, point_tags, initial_value))
    end

    # Add a new Counter metric to the registry
    #
    # @param name [String] metric name
    # @param point_tags [Hash] metric point tags
    # @param initial_value [Integer] metric value
    #
    # @return [Gauge] the gauge object
    def gauge(name, point_tags={}, initial_value = 0)
      'add a new Gauge metric to the registry'
      add(Measurement::Gauge.new(name, point_tags, initial_value))
    end

    def distribution(name, point_tags={}, accuracy: Measurement::Histogram::DEFAULT_ACCURACY,
        granularity: Measurement::Granularity::MINUTE, max_bins: Measurement::Histogram::DEFAULT_MAX_BINS, clock_func: nil)
      add(Measurement::Histogram.new(name, point_tags, accuracy: accuracy, granularity: granularity, max_bins: max_bins, clock_func: clock_func))
    end

    # Check if metric exists
    #
    # @param name [String] name of the metric
    # @return [Bool]
    def exist?(name, point_tags={})
      @store.key?(encode_key(name, point_tags))
    end

    # Get the metric by its name
    #
    # @param name [String] Metric name
    # @param point_tags [Hash] list of metric point tags
    # @return [Metric] the metric value
    def get(name, point_tags={})
      @store[encode_key(name, point_tags)]
    end

    # Get all the metrics in registry
    # @return list of metrics
    def metrics
      @store.values
    end

    # Encode the key using point tags to allow a metric with different point tags
    #
    # @param key [String] name of the metric
    # @param tags [Hash] list of metric point tags
    # @return [String] encoded key
    def encode_key(key, tags)
      key = key.to_s
      if !tags.nil? && !tags.empty?
        key += "-tags=" + tags.to_json
      end
      return key
    end

    # Return the metric value with suffix
    #
    # @param metric [Metric] metric object
    # @return [Hash] metric list
    def get_metric_fields(metric)
      if metric.class == Measurement::Counter
        return {:count => metric.value}
      elsif metric.class == Measurement::Gauge
        return {:value => metric.value}
      else
        return {}
      end
    end
  end
end
