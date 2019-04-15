module Meters
  class Metric
    attr_reader :name, :point_tags

    # @param name [String] metric name
    # @param point_tags [Hash] metric point tags
    def initialize(name, point_tags)
      # TODO: sanitize/validate both?
      @name = name.to_sym
      @point_tags = point_tags&.clone || {}
    end
  end
end
