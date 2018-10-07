require 'logger'

class SearchError < StandardError; end

class AgodaCrawler < BaseCrawler
  BASE_URL = 'https://www.agoda.com'.freeze

  def initialize(site)
    super(site)
  end

  # メモリ対策でその場でsave_dbまでやるメソッド
  def crawl_and_save_db(parser, request, location, formatter)
    area_id, city_flag = parse_params(location.crawl_params)
    total_page = parse_total_page(request, area_id, city_flag)
    # puts "total_page: #{total_page}"
    (1..total_page).each do |page|
      listjson = fetch_listjson(request, page, area_id, city_flag)
      listjson['ResultList'].each do |hotel|
        hotel_info = parser.parse_one_plan(hotel, request, location)
        next unless hotel_info
        formatter.save_db(hotel_info)
      end
    end
  end

  # 一旦hotelsでarrayを溜めるとメモリを食いすぎるのでこのメソッドは使わない
  def get_doc(request, page_num, crawl_params)
    area_id, city_flag = parse_params(crawl_params)
    first_listjson = fetch_listjson(request, 1, area_id, city_flag)
    return unless first_listjson
    total_page = page_num.nil? ? 1 : first_listjson['TotalPage'].to_i
    # puts "total_page: #{total_page}"

    hotels = (1..total_page).flat_map do |page|
      listjson = fetch_listjson(request, page, area_id, city_flag)
      listjson['ResultList']
    end.compact
    # puts "hotels: #{hotels.size}"
    hotels # ホテル情報のJSON配列
  end

  def next_page?(_)
    # GETでページ番号を指定できないので、常にfalse
    false
  end

  private

    def parse_params(params)
      pa = params.split(',')
      area_id = pa[0].to_i
      city_flag = !pa[1].nil?
      [area_id, city_flag]
    end

    def parse_total_page(request, area_id, city_flag)
      first_listjson = fetch_listjson(request, 1, area_id, city_flag)
      return 1 unless first_listjson
      first_listjson['TotalPage'].to_i
    end

    def fetch_listjson(request, page_num, area_id, city_flag)
      post_url = "#{BASE_URL}/api/zh-tw/Main/GetSearchResultList"
      headers = {
        'Content-Type'     => 'application/x-www-form-urlencoded; charset=UTF-8',
        'X-Requested-With' => 'XMLHttpRequest',
        'User-Agent'       => UA_CHROME,
        'Referer'          => build_listpage_url(request, area_id, city_flag),
        # JSONの出力言語はCookieで指定しないと変化しない
        'Cookie'           => 'agoda.version.03=CookieId=9062f421-69a1-4195-b6e4-097795f4ab38&DLang=zh-tw&CurLabel=JPY'
      }
      los = (request.checkout_day - request.checkin_day).to_i # LengthOfStay
      data = {
        CultureInfo:  'zh-TW',
        Cid:          1,
        PageNumber:   page_num,
        PageSize:     50, # 1JSONあたりのレコード数
        SortType:     0,
        CountryName:  'Japan',
        CountryId:    3,
        Rooms:        1,
        Adults:       request.adults.to_i,
        Children:     request.higher_children.to_i + request.lower_children.to_i + request.babys.to_i,
        LengthOfStay: los,
        CheckIn:      request.checkin_day.strftime('%Y-%m-%dT00:00:00')
      }
      if city_flag
        data[:SearchType] = 1
        data[:CityID]     = area_id
      else
        data[:SearchType] = 20
        data[:ObjectID]   = area_id
      end
      data = data.to_a # 'ChildAges[]'は複数入りうるので配列に変換
      build_child_ages(request).each { |age| data << ['ChildAges[]', age] }

      res = post_data(post_url, headers, data)
      return unless res
      JSON.parse(res)
    rescue JSON::ParserError => e
      puts e
      nil
    end

    def build_listpage_url(request, area_id, city_flag)
      result_url = 'https://www.agoda.com/zh-tw/pages/agoda/default/DestinationSearchResult.aspx?' \
                   "#{city_flag ? 'city=' : 'region='}#{area_id}"
      los        = (request.checkout_day - request.checkin_day).to_i # LengthOfStay
      child_num  = request.higher_children.to_i + request.lower_children.to_i + request.babys.to_i
      childages  = build_child_ages(request).join(',')
      params = {
        currencyCode: 'JPY',
        trafficType:  'User',
        checkIn:      request.checkin_day,
        checkOut:     request.checkout_day,
        los:          los,
        rooms:        1,
        adults:       request.adults,
        children:     child_num,
        childages:    childages
      }

      "#{result_url}&#{URI.encode_www_form(params)}"
    end

    def post_data(url, headers = {}, data = {})
      rescue_cnt = 0
      begin
        uri = URI.parse(url)
        https = Net::HTTP.new(uri.host, uri.port)
        https.use_ssl = true

        req = Net::HTTP::Post.new(uri.request_uri)
        headers.each { |k, v| req[k] = v }
        req.body = URI.encode_www_form(data)
        sleep 1
        res = https.request(req)

        case res
        when Net::HTTPSuccess, Net::HTTPRedirection
          res.body
        else
          false
        end
      rescue Errno::EPIPE => e
        raise e if rescue_cnt > 3
        rescue_cnt += 1
        sleep 10
        retry
      end
    end

    def build_child_ages(request)
      [higher_child_age.to_s]  * request.higher_children.to_i \
      + [lower_child_age.to_s] * request.lower_children.to_i \
      + [baby_age.to_s]        * request.babys.to_i
    end

    def baby_age
      3
    end

    def lower_child_age
      7
    end

    def higher_child_age
      11
    end
end
