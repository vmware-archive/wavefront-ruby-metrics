# Wavefront reporter sends data to any wavefront cluster.
# It supports sending data via Direct Ingestion or Proxy.
# Fore more information https://github.com/wavefrontHQ/wavefront-sdk-ruby/blob/master/README.md
#
require_relative 'reporter'
require 'wavefront/client/entities/histogram/histogram_granularity'

module Reporters
  class Wavefront < Reporter
    # @param sender [WavefrontClient] wavefront Direct/Proxy Client
    # @param registry [String] metrics store
    # @param reporting_interval_sec [Integer] interval to report metrics to wavefront
    # @param host [String] host name
    def initialize(sender, application_tags, registry: nil, reporting_interval_sec: 5, host: Socket.gethostname)
      super(registry, reporting_interval_sec)
      @sender = sender
      @host = host
      @application_tags = application_tags.as_dict.freeze
    end

    GMAP = {Measurement::Granularity::MINUTE => MINUTE,
              Measurement::Granularity::HOUR => HOUR,
              Measurement::Granularity::DAY => DAY}.freeze

    # Sends data to Wavefront cluster
    def report_now
      @registry.metrics.each do |data|
        if data.class == Measurement::Counter or data.class == Measurement::Gauge
          result = @registry.get_metric_fields(data)
          @sender.send_metric(data.name.to_s + "." + result.keys[0].to_s, data.value,
                              nil, @host, data.point_tags.merge(@application_tags))
        elsif data.class == Measurement::Histogram
          dist = data.flush_distributions
          dist.each do |dist|
            @sender.send_distribution(data.name, dist.centroids, Set.new([GMAP[dist.granularity]]),
                                      dist.timestamp.to_i, @host, data.point_tags.merge(@application_tags))
          end
        else
          puts "Metrics type not supported"
        end
      end
    end
  end
end