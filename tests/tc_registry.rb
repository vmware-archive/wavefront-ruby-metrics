require 'test/unit'
require_relative '../registry'
require_relative '../histogram/histogram'
require_relative '../meters/metric'
require_relative '../meters/counter'
require_relative '../meters/gauge'

class RegistryTests < Test::Unit::TestCase
  class NotMetric; end

  def test_types
    r = Registry::MetricsRegistry.new
    c0 = r.counter(:counter_0, nil, 0)
    r.counter(:counter_1, {}, 1)
    r.gauge(:gauge, nil, 1)
    r.distribution(:dist, nil)

    assert_raise TypeError do
      r.add(NotMetric.new)
    end

    assert(r.exist?(:counter_0))
    assert_kind_of(Meters::Counter, r.get(:counter_0))
    assert_same(c0, r.get(:counter_0))
    assert_kind_of(Meters::Gauge, r.get(:gauge))
    assert_kind_of(Meters::Histogram, r.get(:dist))

    # Delete
    r.del(:gauge)
    assert_equal(nil, r.get(:gauge))

    # Test uniqueness
    assert_raise Registry::MetricsRegistry::DuplicateKeyError do
      r.counter(:counter_1, nil, 10)
    end
  end

  def test_concurrent_reads
    r = Registry::MetricsRegistry.new
    r.counter(:counter, nil, 10)

    threads = 10.times.map do
      Thread.new do
        1000.times do
          assert_equal(10, r.get(:counter).value)
        end
      end
    end
    threads.each(&:join)
  end

  def test_concurrent_writes
    r = Registry::MetricsRegistry.new
    threads = 20.times.map do
      Thread.new do
        begin
          r.counter(:same_name, nil, 1)
          0
        rescue Registry::MetricsRegistry::DuplicateKeyError
          1
        end
      end
    end
    assert_equal(19, threads.map(&:join).map(&:value).inject(&:+))
  end
end
