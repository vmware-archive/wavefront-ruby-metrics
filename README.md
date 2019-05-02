# wavefront-ruby-metrics [![Build Status](https://travis-ci.com/wavefrontHQ/wavefront-ruby-metrics.svg?branch=master)](https://travis-ci.com/wavefrontHQ/wavefront-ruby-metrics)

Captures application-level metrics (counters, gauges & histograms) for your ruby code.

## Requirements and Installation
Ruby version >= 2.3.0 is supported.

```
gem install wavefront-metrics
```

## Core Features
### Counter
Counters show information over time. Think of a person with a counter at the entrance to a concert. The counter shows the total number of people that have entered so far. Counters usually increase over time but might briefly go to zero.
### Gauge
A gauge shows the current value for each point in time. Think of a thermometer that shows the current temperature or a gauge that shows how much electricity your Tesla has left.

### Histogram
a mechanism to compute, store, and use distributions of metrics.

## Examples
### Counter
```ruby
require 'wavefront/metrics'

def test
  $test_count.inc
  # your business logic
end

store = Registry::MetricsRegistry.new
$test_count = store.counter("test.call", {"tag1"=>"value1", "tag2"=>"value2"}, 0)
5.times do
  test
end

puts $test_count.value         # 5
puts $test_count.name          # test.call
puts $test_count.point_tags    # {"tag1"=>"value1", "tag2"=>"value2"}
```
#### Gauge
```ruby
require 'wavefront/metrics'

store = Registry::MetricsRegistry.new
test_gauge = store.gauge("test.gauge", {"tag1"=>"value1", "tag2"=>"value2"}, 0)
test_gauge.set(10)

puts test_gauge.value         # 10.0
puts test_gauge.name          # test.gauge
puts test_gauge.point_tags    # {"tag1"=>"value1", "tag2"=>"value2"}
 ```
#### Histogram
```ruby
require 'wavefront/metrics'

store = Registry::MetricsRegistry.new
test_hist = store.distribution("test.histogram", {"tag1"=>"value1", "tag2"=>"value2"})
test_hist.push(0.1)
test_hist.push(1)
test_hist.push(10)
sleep(61) # To generate histogram

puts test_hist.name          # test.histogram
puts test_hist.point_tags    # {"tag1"=>"value1", "tag2"=>"value2"}
puts test_hist.min           # 0.1
puts test_hist.max           # 10
puts test_hist.mean          # 3.6999999999999997
 ```
## Reporter
### Wavefront
Wavefront reporter is used to reporting collected data to the Wavefront cluster via proxy or direct ingestion.
For more information about creating wavefront sender [click here](https://github.com/wavefrontHQ/wavefront-sdk-ruby/blob/master/README.md)
```ruby
require 'wavefront/metrics'
require 'wavefront/client'


def test
    $test_count.inc
    # your business logic
end

client = Wavefront::WavefrontDirectIngestionClient.new(server, token)
store = Registry::MetricsRegistry.new
reporter = Reporters::Wavefront.new(client, Wavefront::ApplicationTags.new(application="beachshirts", service="shopping", cluster: "us-west-2", shard: "primary"), registry: store)

$test_count = store.counter("test.call", {"tag1"=>"value1", "tag2"=>"value2"}, 0)
5.times do
    test
end

reporter.stop
 ```    
