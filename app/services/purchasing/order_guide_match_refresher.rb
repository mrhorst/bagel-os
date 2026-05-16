module Purchasing
  class OrderGuideMatchRefresher
    def initialize(matcher: ProductNameMatcher.new, linking: nil)
      @linking = linking || OrderGuideLinking.new(matcher: matcher)
    end

    def refresh!
      linking.refresh_all!
    end

    private

    attr_reader :linking
  end
end
