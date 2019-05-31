# Internal Diagnostic Metrics

This SDK automatically collects a set of diagnostic metrics that allow you to monitor your Wavefront reporter instance. These metrics are collected once per minute and are reported to Wavefront using your `WavefrontClient` instance.

The following is a list of the diagnostic metrics that are collected:

|Metric Name|Metric Type|Description|
|:---|:---:|:---|
|~sdk.ruby.metrics.reporter.gauges.reported.count                           |Counter    |Times that gauges are reported|
|~sdk.ruby.metrics.reporter.counters.reported.count              |Counter    |Times that non-delta counters are reported|
|~sdk.ruby.metrics.reporter.wavefront_histograms.reported.count  |Counter    |Times that Wavefront histograms are reported|
|~sdk.ruby.metrics.reporter.errors.count                         |Counter    |Exceptions encountered while reporting|

Each of the above metrics is reported with the same source and application tags that are specified for your Wavefront metrics reporter.

For information regarding diagnostic metrics for your Wavefront Client instance, [see here](https://github.com/wavefrontHQ/wavefront-sdk-ruby/blob/master/docs/internal_metrics.md).