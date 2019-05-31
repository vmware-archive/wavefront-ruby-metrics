# frozen_string_literal: true

# Wavefront reporter sends data to any wavefront cluster.
# It supports sending data via Direct Ingestion or Proxy.
# Fore more information https://github.com/wavefrontHQ/wavefront-sdk-ruby/blob/master/README.md
#
require 'wavefront/client'
require 'wavefront/client/internal-metrics/registry'
require_relative 'reporter'

module Reporters
  class Wavefront < Reporter
    attr_reader :default_source
    # @param sender [WavefrontClient] wavefront Direct/Proxy Client
    # @param registry [String] metrics store
    # @param reporting_interval_sec [Integer] interval to report metrics to wavefront
    # @param host [String] host name
    def initialize(sender, application_tags, registry: nil, reporting_interval_sec: 5, host: Socket.gethostname)
      @sender = sender
      @default_source = host
      @application_tags = application_tags.as_dict.freeze
      @internal_store = ::Wavefront::InternalMetricsRegistry.new(::Wavefront::SDK_METRIC_PREFIX + ".metrics.reporter", @application_tags)
      @gauges_reported = @internal_store.counter("gauges.reported");
      @counters_reported = @internal_store.counter("counters.reported");
      @wfhistograms_reported = @internal_store.counter("wavefront_histograms.reported");
      @report_errors = @internal_store.counter("errors");

      @internal_reporter = ::Wavefront::InternalReporter.new( @sender, @internal_store)
      super(registry, reporting_interval_sec)
    end

    GMAP = { Measurement::Granularity::MINUTE => ::Wavefront::MINUTE,
             Measurement::Granularity::HOUR => ::Wavefront::HOUR,
             Measurement::Granularity::DAY => ::Wavefront::DAY }.freeze

    # Sends data to Wavefront cluster
    def report_now
      @registry.metrics.each do |data|
        begin
          if (data.class == Measurement::Counter) || (data.class == Measurement::Gauge)
            result = @registry.get_metric_fields(data)
            @sender.send_metric(data.name.to_s + '.' + result.keys[0].to_s, data.value,
                                (Time.now.to_f * 1000).round, @default_source, data.point_tags.merge(@application_tags))

            if data.class == Measurement::Counter
              @counters_reported.inc
            else
              @gauges_reported.inc
            end

          elsif data.class == Measurement::Histogram
            dist = data.flush_distributions

            dist.each do |dist|
              @sender.send_distribution(data.name, dist.centroids, Set.new([GMAP[dist.granularity]]),
                                        dist.timestamp.to_i, @default_source, data.point_tags.merge(@application_tags))
            end

            @wfhistograms_reported.inc
          else
            Wavefront.logger.warn 'Metric is dropped by the reporter for type: #{data.class}'
          end
        rescue StandardError => e
          @report_errors.inc
          Wavefront.logger.warn 'Unable to report to Wavefront. Error: #{e}'
        end
      end
    end
  end
end