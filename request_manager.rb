require_relative 'common.rb'

class RequestManager
  def self.get_location
    count_location = Location.where(status:0).count
    if SERVER_NAME == RESERVATION && count_location > 0#ジョブがあるときには正常
      if Location.where(status:0,reservation_flag:1).count > 0
        location = Location.where(status:0,reservation_flag:1).first
      else
        location = Location.where(status:0).first
      end
    elsif count_location > 0
      if Location.where(status:0,reservation_flag:0).count > 0
        location = Location.where(status:0,reservation_flag:0).first
      else
        location = Location.where(status:0).first
      end
    else
      exit #未実行locaationナシの場合処理終了
    end
  end
  
  def self.location_run(location)
    begin
      location.update(status:1, server: SERVER_NAME, retry_count:"#{location.retry_count}")
    rescue
      exit
    end
  end

  def self.location_check(request)# 実行中のリクエストの全てのロケーションのクローリングが終了した時にstatusを2か3に変更
    if Location.where(status:0,request_id:request.id,site:request.site_code).or(Location.where(status:1,request_id:request.id,site:request.site_code)).count == 0
      if Location.where(status:3,request_id:request.id,site:request.site_code).count > 0
        RequestManager.retry_count_less_three(request)#実行回数が3回以下の時はstatusを0に戻す
        RequestManager.three_run?(request)#3回リトライしてダメだった場合は諦めて処理を抜ける。
      else
        request.update(status:2)#正常終了した場合、リクエストのステータスを2に更新
        exit
      end
    end
  end
  
  def self.error_check(request)# 5回以上失敗している場合、異常値なのでいったん処理を抜ける。
    if Location.where(status:3,request_id:request.id,site:request.site_code).count > 10
      Location.where(request_id:request.id,site:request.site_code,status:0).update_all(status:3,result:'ERROR104',message:'連続してエラーが発生した為、クロールを停止致しました')
      request.update(status:3,result:'ERROR104',message:'連続してエラーが発生した為、クロールを停止致しました')
      exit
    end
  end

  def self.retry_count_less_three(request)
    Location.where(status:3,request_id:request.id,site:request.site_code).find_each do |location|
      location.update(status:0,retry_count: location.retry_count + 1) if location.retry_count < 3# 異常終了エリアが３回再実行していなければstatusを0に戻す
    end
  end

  def self.three_run?(request)
    if Location.where(retry_count:3,request_id:request.id,site:request.site_code).count > 0
      request.update(status:3,result:'ERROR101',message:'3回リトライに失敗しました。')
      Location.where(retry_count:3,request_id:request.id,site:request.site_code).update(status:3,result:'ERROR101',message:'3回リトライに失敗しました。')
      exit
    end
  end

  def self.running_location?# すでに稼働中のlocationが無いか確認する
    locations = Location.where(status:1, server: SERVER_NAME).count# status=1のレコードがあれば、稼働中Job有り
    return locations == 0 ? false : true
  end
  
  def self.perform_location?(running_request_all)
    running_request_all.each do |request|
      return true if Location.where(status:0,request_id:request.id).count > 0
    end
    return false
  end

  def self.running_request
    request = Request.where(status:1).first
  end

  def self.running_request_all
    request = Request.where(status:1)
  end

  def self.get_request
    requests = Request.where(status:0)
  end
  
  def self.location_request(location)
    request = Request.where(status:1,id:location.request_id,do_exit:0).first
    return Request.where(status:1,id:location.request_id).count > 0 ? request : exit
  end

  def self.request_run(request)
    compel_exit(request) if exit?(request)
    if Location_master.where(site:request.site_code,delete_flag:0).count == 0
      request.update(status:2)
      exit
    end
    record = Price.where(request_id:request.id)#もし仮に同一のrequest_idで既にレコードが存在しているのであれば削除する。
    record.destroy_all if record.count > 0
    request.update(status:1)
  end

  def self.location_insert(request,logger)
    @formatter = Formatter.new(logger)
    if request.reservation_flag == 1 && request.site_code == JALAN_CODE
      @formatter.reserv_location(request)
    else
      @formatter.location_insert(request)
    end
  end

  def self.mark_completed(request)# ジョブの完了をテーブルに記録
      request.update(status: 2)
  end
  
  def self.exit?(request)# jobsテーブルのdo_exitカラムが0:処理継続, 1:強制終了
    request.reload.do_exit == 1
  end

  def self.compel_exit(request)# ジョブの強制終了
    request.update(status: 4)
    Location.where(request_id:request.id,status:0).update_all(status:4)
    exit
  end

  def self.check_start_end_date(request)
    if request.checkin_day > request.checkout_day
      request.update(result:"ERROR300" , message: "チェックイン日がチェックアウト日を超えて登録されています。", status:3)
      exit
    end
  end

  def self.check_start_date(request)
    if request.checkin_day.strftime("%Y-%m-%d") < Date.today.strftime("%Y-%m-%d")
      request.update(result:"ERROR301" , message: "チェックイン日に過去の日付が登録されています。", status:3)
      exit
    end
  end

  def self.check_date_format(request)
    unless request.checkin_day.strftime("%Y-%m-%d").match(/^\d{4}-\d{2}-\d{2}$/) && request.checkout_day.strftime("%Y-%m-%d").match(/^\d{4}-\d{2}-\d{2}$/) 
      request.update(result:"ERROR302" , message: "正しい形式で日付が登録されていません。", status:3)
      exit
    end
  end

  def self.check_search_period(request)
    case request.site_code
      when JALAN_CODE
        # 9泊以上の予約不可
        operating_period = request.checkin_day + 9
      when BOOKING_CODE
        # 30泊以上の予約不可
        operating_period = request.checkin_day + 30
      when IKYU_CODE
        # 9泊以上の予約不可
        operating_period = request.checkin_day + 9
      else
        return nil
    end
  
    if request.checkout_day > operating_period
      request.update(result:"ERROR303" , message: "予約可能な宿泊数を超えています。", status:3)
      exit
    end 
  end

  def self.check_total_number_people(request)
    # 10人以上の場合は終了
    total_ppl = request.adults.to_i + request.higher_children.to_i + request.lower_children.to_i + request.babys.to_i
    if total_ppl > 9
      request.update(result:"ERROR304" , message: "予約可能な人数を超えています。", status:3)
      exit
    end
  end
end
