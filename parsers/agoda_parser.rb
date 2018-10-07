class AgodaParser < BaseParser
  BASE_URL = 'https://www.agoda.com'.freeze

  def initialize(site)
    super(site)
  end

  # 各プランをパース (メモリが足りないので使わない)
  # agodaでは[{ "HotelID": 1076714, "SupplierId": ... }, ...]というhashのarrayをdocとして受け取っている
  def parse_plan(doc, request, location)
    raise '件数が取得できませんでした' unless plan_exists?(doc)
    # puts "crawl area: #{location.area}"
    doc.uniq! { |hotel| hotel['HotelID'] }
    all_plans = doc.map { |hotel| parse_one_plan(hotel, request, location) }.compact
    raise '件数が取得できませんでした' unless plan_exists?(all_plans)
    all_plans
  end

  def plan_exists?(doc)
    !doc.size.zero?
  end

  def filter_lowest_plan(plans)
    # agodaでは必要なし
    plans
  end

  # hotel (hash) を元にplanを作る
  def parse_one_plan(hotel, request, location)
    return if Price.exists?(request_id: request.id, hotel_id: hotel['HotelID'])
    hotel_info = {
      request_id: request.id,
      area:       location.area.rstrip,
      hotel_id:   hotel['HotelID'],
      hotel_name: hotel['TranslatedHotelName']
    }
    room_info = fetch_room_info(request, hotel)
    return unless room_info
    hotel_info.merge!(room_info)
  end

  private

    def fetch_room_info(request, hotel)
      hotel_uri = "#{BASE_URL}#{hotel['HotelUrl']}"
      hotel_info = fetch_room_info_json(hotel_uri)
      return if hotel_info.blank?
      cheapest = find_cheapest_plan(hotel_info)
      parse_room_info(request, cheapest)
    end

    def fetch_room_info_json(url)
      sleep 1
      html = open(url, allow_redirections: :all, read_timeout: 120).read
      json_text = html.match(/masterRooms\:\s.*/).to_a[0]
      # 全プランが売り切れていた場合 'masterRooms:' という文字列が存在しないので、return
      return if json_text.blank?
      json_text = json_text.sub(/masterRooms\:\s/, '').sub(/,\r$/, '')
      json = JSON.parse(json_text)
      return if json.blank?
      json
    end

    # 割引後の価格が一番安いplanを返す
    def find_cheapest_plan(hotel_info)
      min_room = hotel_info.min_by do |hotel|
        hotel['rooms'].map { |room| room['exclusivePrice']['display'].to_i }.min
      end
      min_room['rooms'].min_by { |plan| plan['exclusivePrice']['display'].to_i }
    end

    def parse_room_info(request, room)
      room_type  = room['name']
      plan_price = room['exclusivePrice']['display'].to_i
      tax_n_sur  = room['totalPrice']['display'].to_i - plan_price
      is_multiple_plan = multiple_plan?(request, room)

      {
        plan_id:   nil,
        plan_name: room_type,
        plan_url:  nil,
        room_type: room_type,
        price:     plan_price,
        additional_price: tax_n_sur,
        is_multiple_plan: is_multiple_plan
      }
    end

    def multiple_plan?(request, plan)
      capacity_num = plan['occupancy'].to_i + plan['maxFreeChildren'].to_i
      return unless capacity_num
      will_stay_num = request.adults.to_i + request.babys.to_i + request.lower_children.to_i + request.higher_children.to_i
      (capacity_num != will_stay_num)
    end
end
