require_relative '../common.rb'

class RakutenParser < BaseParser

  def initialize(site)
    super(site)
  end

  def parse_plan(doc, request, location)# 各プランをパース
    raise '件数が取得できませんでした' unless plan_exists?(doc)
    hotel_datas = []
    doc.css('#htlBox > li').each do |hotel|
      attention_hotel = hotel.css('.htlGnrlInfo .attnTxt').text
      if attention_hotel.blank? # 注目ホテルは重複のため飛ばす
        hotel_data = {}
        # request情報取得
        hotel_data['request_id'] = request.id.to_i
        hotel_data['area'] = location.area.rstrip.split(' ')[0]
        # ホテル情報取得
        hotel_data['hotel_id'] = hotel.at_css('.htlGnrlInfo h2 a')['id'].gsub(/_link/, '')
        hotel_data['hotel_name'] = hotel.at_css('.htlGnrlInfo h2 a').text
        # plan情報取得
        plan = hotel.css('.plnBox .plans')[0]
        hotel_data['price'] = plan.css('.vPrice strong').text.gsub(/,/,'').to_i
        plan_id = plan.attributes['id'].value.split("-")[3] unless plan.attributes['id'].value.split("-")[3] == '0'
        hotel_data['plan_id'] = plan_id
        hotel_data['plan_name'] = plan.css('.plnNm a').text
        plan_url = plan.at_css('.plnNm a')['href']
        plan_url = "https:#{plan_url}" if plan_url.match(/^https?/).nil?
        hotel_data['plan_url'] = plan_url
        hotel_data['room_type'] = plan.css('.bedNm').text
        hotel_datas << hotel_data
      end
    end
    return hotel_datas
  end

  def filter_lowest_plan(parsed_all_plans)# 最安値の判断ロジック
    # 楽天では不要
    return parsed_all_plans
  end

private
  def plan_exists?(doc)# 件数がゼロ件か否かの判定用メソッド。
    return doc.at_css('#listError').blank?
  end  
end
