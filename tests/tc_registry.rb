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
    r.counter(:counter_1, {}, 10)
    r.gauge(:gauge, nil, 1)
    r.distribution(:dist, {})

    assert_raise TypeError do
      r.add(NotMetric.new)
    end

    assert(r.exist?(:counter_0, {}))
    assert_kind_of(Measurement::Counter, r.get(:counter_0,{}))
    assert_same(c0, r.get(:counter_0,{}))
    assert_kind_of(Measurement::Gauge, r.get(:gauge,{}))
    assert_kind_of(Measurement::Histogram, r.get(:dist,{}))

    # Delete
    r.del(:gauge,{})
    assert_equal(nil, r.get(:gauge,{}))

    # Test uniqueness
    assert_equal(10, r.counter(:counter_1, {}, 25).value)
  end

  def test_concurrent_reads
    r = Registry::MetricsRegistry.new
    r.counter(:counter, nil, 10)

    threads = 10.times.map do
      Thread.new do
        1000.times do
          assert_equal(10, r.get(:counter,{}).value)
        end
      end
    end
    threads.each(&:join)
  end

  def test_concurrent_writes
    r = Registry::MetricsRegistry.new
    r.counter(:same_name, nil, 1)
    threads = 23.times.map do |x|
      Thread.new do
        begin
          r.counter(:same_name, nil, 7 + 10 * x)
        end
      end
    end

    assert_equal(23, threads.map(&:join).map(&:value).map(&:value).inject(&:+))
  end

  def test_with_point_tags
    store = Registry::MetricsRegistry.new
    metric_name = "api.count"
    point_tags = {"key-1" => "val-1", "key-2" => "val-2"}
    new_point_tags = {"key-3" => "val-3", "key-4" => "val-4"}

    # Add same metric with different point tags
    store.counter(metric_name, point_tags, 5)
    store.counter(metric_name, new_point_tags, 10)

    # Verify the metric value
    assert_equal(5, store.get(metric_name,point_tags).value)
    assert_equal(10, store.get(metric_name,new_point_tags).value)

    # Delete the metric
    store.del(metric_name, point_tags)

    # verify the deletion
    assert_equal(nil, store.get(metric_name,point_tags))

  end
end
