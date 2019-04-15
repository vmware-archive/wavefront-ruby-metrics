require 'test/unit'
require 'concurrent'
require_relative '../histogram/histogram'

include Meters
class HistogramTests < Test::Unit::TestCase
  def setup
    @clock = Concurrent::AtomicFixnum.new(0)
  end

  def get_time
    @clock.value
  end

  def new_hist
    Histogram.new('Histogram-1', nil, Histogram::DEFAULT_ACCURACY, Granularity::MINUTE, Histogram::DEFAULT_MAX_BINS, method(:get_time))
  end

  def create_pow10
    pow10 = new_hist
    pow10.push(0.1)
    pow10.push(1.0)
    pow10.push(1e1)
    pow10.push(1e1)
    pow10.push(1e2)
    pow10.push(1e3)
    pow10.push(1e4)
    pow10.push(1e4)
    pow10.push(1e5)
    @clock.increment(60_000 + 1)
    pow10
  end

  def test_new
    d = Distribution.new(nil, nil, nil)
    s = Snapshot.new(nil)
    h = Histogram.new('Histogram-1', {})
  end

  def test_methods
    pow10 = create_pow10
    assert_equal(9, pow10.count)
    assert_in_delta(121_121.1, pow10.sum)
    assert_in_delta(13_457.9, pow10.mean)
    assert_in_delta(0.1, pow10.min)
    assert_in_delta(1e5, pow10.max)
  end

  def test_flush
    pow10 = create_pow10
    assert_equal(9, pow10.count)
    dists = pow10.flush_distributions
    assert_equal(0, pow10.count)
    assert_equal(0, pow10.snapshot.count)

    assert_equal(1, dists.size)
    assert_equal(7, dists[0].centroids.size)
    assert_kind_of(Distribution, dists[0])
    assert_equal(Granularity::MINUTE, dists[0].granularity)
  end

  def test_snapshot
    pow10 = create_pow10
    assert_kind_of(Snapshot, pow10.snapshot)
    snap = pow10.snapshot
    assert_equal(9, snap.count)
    assert_in_delta(121_121.1, snap.sum)
    assert_in_delta(13_457.9, snap.mean)
    assert_in_delta(0.1, snap.min)
    assert_in_delta(0.1, snap.percentile(0))
    assert_in_delta(1e5, snap.max)
  end

  def dist_gather(dist)
    dmap = Hash.new { |hash, key| hash[key] = 0 }
    dist.flat_map(&:centroids).each do |c|
      dmap[c[0]] = dmap[c[0]] + c[1]
    end
    dmap
  end

  def test_concurrent
    def cen(m, n)
      TDigest::Centroid.new(m, n, n)
    end
    cens1 = [cen(21.2, 70), cen(82.35, 2), cen(1042, 6)]
    cens2 = [cen(24.2, 80), cen(84.35, 1), cen(1002.0, 9)]
    cens3 = [cen(21.2, 60), cen(84.35, 12), cen(1052.0, 8)]

    hm = new_hist
    hm.push_centroid(cens1)

    t1 = Thread.new do
      hm.push_centroid(cens2)
    end
    t2 = Thread.new do
      hm.push_centroid(cens3)
    end

    sleep(1)
    @clock.increment(60_000 + 1)
    dist = hm.flush_distributions
    t1.join; t2.join

    expected_dmap = { 21.2 => 130, 82.35 => 2, 1042 => 6, 84.35 => 13, 1052.0 => 8, 24.2 => 80, 1002.0 => 9 }

    assert_equal(expected_dmap, dist_gather(dist))
  end
end
