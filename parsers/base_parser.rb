require_relative '../common.rb'

class BaseParser

  def initialize(site)
    @site = site
  end

  def self.factory(site)
    case site
    when RAKUTEN_CODE
      RakutenParser.new(site)
    when JALAN_CODE
      JalanParser.new(site)
    when BOOKING_CODE
      BookingParser.new(site)
    when IKYU_CODE
      IkyuParser.new(site)
    when AGODA_CODE
      AgodaParser.new(site)
    end
  end

  def plan_exists?(doc)
    raise NotImplementedError.new('plan_exists? must be overridden by BaseParser subclasses')
  end

  def parse_plan(doc)
    raise NotImplementedError.new('parse_plan must be overridden by BaseParser subclasses')
  end

  def filter_lowest_plan(parsed_all_plans)
    raise NotImplementedError.new('filter_lowest_plan must be overridden by BaseParser subclasses')
  end
end
