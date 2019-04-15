require 'test/unit'
require_relative '../meters/metric'
require_relative '../meters/counter'
require_relative '../meters/gauge'

class TestMetrics < Test::Unit::TestCase
  def test_metric_base
    m = Meters::Metric.new('metric', nil)
    assert_equal(:metric, m.name)
    assert_kind_of(Hash, m.point_tags)

    # point tags
    pt = { 'tag1' => 'value1', 'tag2' => 2 }
    m2 = Meters::Metric.new('m2', pt)
    assert_equal(2, m2.point_tags.size)
    assert_equal('value1', m2.point_tags['tag1'])
    assert_equal(2, m2.point_tags['tag2'])

  end

  def test_counter_parallel
    c = Meters::Counter.new('test', nil, 0)
    threads = 10.times.map do
      Thread.new do
        1000.times do
          c.inc
        end
      end
    end
    threads.each(&:join)
    assert_equal(10_000, c.value)
  end

  def test_gauge_types
    g = Meters::Gauge.new('int', nil, 0)
    g.set(10)
    g.value = 10
    assert_equal(10, g.value)
    assert_kind_of(Float, g.value)

    g = Meters::Gauge.new('float', nil, 0)
    g.set(1.23456)
    g.value = 1.23456
    assert_equal(1.23456, g.value)
    assert_kind_of(Float, g.value)
  end

  def test_gauge_parallel
    g = Meters::Gauge.new('gauge', nil, 0)
    threads = 31.times.map do |i|
      Thread.new do
        g.set(1 << i)
      end
    end
    threads.each(&:join)
    assert_equal(1, g.value.to_i.to_s(2).count('1'))
  end
end
