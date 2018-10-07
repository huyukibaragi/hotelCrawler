require 'logger'
require_relative '../common.rb'

class SearchError < StandardError; end

class BaseCrawler
  def initialize(site)
    @site = site
  end

  def self.factory(site)
    case site
    when RAKUTEN_CODE
      RakutenCrawler.new(site)
    when JALAN_CODE
      JalanCrawler.new(site)
    when BOOKING_CODE
      BookingCrawler.new(site)
    when IKYU_CODE
      IkyuCrawler.new(site)
    when AGODA_CODE
      AgodaCrawler.new(site)
    end
  end

  # HTML取得
  def self.get_html_doc(uri, charset = 'UTF-8')
    html = open(uri, allow_redirections: :all).read
    sleep 1 # マナーはしっかりスリープ1秒
    doc = Nokogiri::HTML.parse(html, nil, charset)
  end
end
