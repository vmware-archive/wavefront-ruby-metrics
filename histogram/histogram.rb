# Metric which calculates the distribution of a value
#
require 'tdigest'

require_relative '../meters/metric'

module Meters

  class Granularity
    MINUTE = 60 * 1000
    HOUR = MINUTE * 60
    DAY = HOUR * 24
  end

  class Distribution
    attr_accessor :timestamp, :centroids, :granularity
    def initialize(timestamp, centroids, granularity)
      @timestamp = timestamp
      @centroids = centroids
      @granularity = granularity
    end
  end

  class Snapshot
    def initialize(dist)
      @dist = dist
    end

    # Get the size of the distribution
    def count
      @dist&.size
    end

    # Get the sum of the distribution
    def sum
      @dist&.centroids.values.reduce(0) { |s, c| s + (c.mean * c.n) }
    end

    # Get the mean of the distribution
    def mean
      sum / @dist&.size
    end

    # Get the minimum of the distribution
    def min
      @dist&.centroids.first[1].mean
    end

    # Get the maximum of the distribution
    def max
      @dist&.centroids.last[1].mean
    end

    # Find value that is at the given percentile
    def percentile(p)
      @dist&.percentile(p)
    end
  end

  

  class Histogram < Meters::Metric
    DEFAULT_ACCURACY = 100
    DEFAULT_MAX_BINS = 10

    attr_reader :granularity, :accuracy, :max_bins

    def initialize(name, point_tags, accuracy = DEFAULT_ACCURACY, granularity = Granularity::MINUTE, max_bins = DEFAULT_MAX_BINS, clock_func = nil)
      super(name, point_tags)
      @mutex = Mutex.new
      @accuracy = accuracy
      @max_bins = max_bins
      @granularity = granularity
      @past_bins = []
      @clock_func = clock_func || method(:_now)
      @current_bin = PerThreadTimedBin.new(_granular_now, @accuracy, granularity)
    end

    def push(val)
      get_current_bin.push(Thread.current, val)
    end

    def push_centroid(c)
        get_current_bin.push_centroid(Thread.current, c)
    end

    def flush_distributions
      flushable_bins = get_past_bins
      dists = nil
      @mutex.synchronize do
        dists = flushable_bins.flat_map(&:to_distribution)
        @past_bins = []
      end
      dists
    end

    def snapshot
      dist = TDigest::TDigest.new(1.0 / @accuracy)
      get_past_bins.flat_map(&:values).each {|td| dist+= td }
      Snapshot.new(dist)
    end

    def count
      get_past_bins.flat_map(&:values).map!(&:size).reduce(0, &:+)
    end

    def sum
      get_past_bins.flat_map(&:values).flat_map { |td| td.centroids.values }.reduce(0) do |sum, c|
        sum + (c.mean * c.n)
      end
    end

    def mean
      sum / count
    end

    def min
      get_past_bins.flat_map(&:values).reduce(Float::INFINITY) do |min, td|
        mm = td.centroids.first[1].mean
        min < mm ? min : mm
      end
    end

    def max
      get_past_bins.flat_map(&:values).reduce(-Float::INFINITY) do |max, td|
        mm = td.centroids.last[1].mean
        max > mm ? max : mm
      end
    end

    private

    class PerThreadTimedBin
        attr_reader :gtime, :granularity, :thread_bins
        def initialize(gtime, accuracy, granularity)
          @accuracy = accuracy
          @thread_bins = Hash.new { |hash, key| hash[key] = TDigest::TDigest.new(1.0 / @accuracy) }
          @gtime = gtime.to_i
          @granularity = granularity
        end
    
        def push(tid, val)
          @thread_bins[tid].push(val)
        end
    
        def push_centroid(tid, centroid)
          @thread_bins[tid].push_centroid(centroid)
        end
    
        def values
          @thread_bins.values
        end
    
        def to_distribution
          dists = []
          @thread_bins.values.each do |td|
            dcen = td.centroids.values.map! { |c| [c.mean, c.n] }
            dists << Distribution.new(@gtime, dcen, @granularity)
          end
          dists
        end
    end

    def _now
      (Time.now.to_f * 1000).round
    end

    # Current epoch milliseconds truncated to granularity
    def _granular_now
      now = @clock_func.call
      now - now.modulo(@granularity)
    end

    def _rotate_bins
      return @current_bin if @current_bin.gtime == _granular_now # fast path

      @mutex.synchronize do
        gnow = _granular_now
        if @current_bin.gtime != gnow
          @past_bins << @current_bin
          @past_bins = @past_bins.last(@max_bins)
          @current_bin = PerThreadTimedBin.new(gnow, @accuracy, @granularity)
        end
        @current_bin
      end
    end

    def get_current_bin
      _rotate_bins
    end

    def get_past_bins
      _rotate_bins
      @past_bins
    end
  end
end
