require_relative 'common.rb'

class Formatter
  def initialize(logger)
    @log = logger
  end
  
  def save_db(db_rows)
    Price.create(db_rows)
  end
  
  def location_insert(request)
    all_locations = []
    exitst_record = Location.where(request_id:request.id)#もし仮に同一のrequest_idで既にレコードが存在しているのであれば削除する。
    exitst_record.destroy_all if exitst_record.count > 0
    locations = Location_master.where(site: request.site_code, delete_flag: 0)    
    locations.each do |location|
      location_row = {}
      location_row['request_id'] = request.id
      location_row['site'] = location.site
      location_row['area'] = location.area
      location_row['crawl_params'] = location.crawl_params
      location_row['status'] = 0
      location_row['retry_count'] = 0
      location_row['reservation_flag'] = request.reservation_flag
      location_row['is_count_error_flag'] = location.is_count_error_flag if location.site == RAKUTEN_CODE || location.site == JALAN_CODE
      location_row['created_at'] = Time.now
      location_row['updated_at'] = Time.now
      all_locations << location_row
    end
        
    Location.create(all_locations)
  end

  def reserv_location(request)
    all_hotels = []
    hotels = Hotel_master.where(is_delete: 0, site: JALAN_CODE)    
    hotels.each do |hotel|
      hotel_row = {}
      crawl_params = hotel.area + ',' + hotel.hotel_name + ',' + hotel.hotel_id
      hotel_row['request_id'] = request.id
      hotel_row['site'] = JALAN_CODE
      hotel_row['area'] = hotel.area
      hotel_row['crawl_params'] = crawl_params
      hotel_row['status'] = 0
      hotel_row['retry_count'] = 0
      hotel_row['reservation_flag'] = 1
      hotel_row['created_at'] = Time.now
      hotel_row['updated_at'] = Time.now
      all_hotels << hotel_row
    end
    Location.create(all_hotels)
  end
end
