require 'logger'
require_relative '../common.rb'

class SearchError < StandardError;
end

class RakutenCrawler < BaseCrawler
  def initialize(site)
    super(site)
  end

  def get_doc(request, page_num, crawl_params)
    checkin_day = request.checkin_day.strftime("%Y-%-m-%-d").split('-')
    checkout_day = request.checkout_day.strftime("%Y-%-m-%-d").split('-')
    url_params = "&f_sort=hotel_kin_low&f_nen1=#{checkin_day[0]}&f_tuki1=#{checkin_day[1]}&f_hi1=#{checkin_day[2]}&f_nen2=#{checkout_day[0]}&f_tuki2=#{checkout_day[1]}&f_hi2=#{checkout_day[2]}&f_heya_su=1&f_otona_su=#{request.adults.to_s}&f_s1=#{request.higher_children.to_s}&f_s2=#{request.lower_children.to_s}&f_y1=#{request.babys.to_s}&f_tab=hotel&f_dai=japan&f_hyoji=100&f_page=#{page_num.to_s}"
    url = crawl_params + url_params
    return BaseCrawler.get_html_doc(url, charset = 'UTF-8')
  end

  def next_page?(doc)
    return doc.css('.pagingBack').text == '' ? false : true
  end  
end
