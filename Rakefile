require_relative 'common.rb'
require_relative 'request_manager.rb'
$retry_errormessage = "ジョブ異常終了メールです。"

desc "最新データのスクレイピングからDB出力"
task :all do
  if running_request_all = RequestManager.running_request_all
    while RequestManager.perform_location?(running_request_all) do
      sleep(1); next if RequestManager.running_location?
      location = RequestManager.get_location
      exit unless request = RequestManager.location_request(location)
      RequestManager.location_run(location)
      Rake::Task['site_crawl'].invoke(location,request)
      Rake::Task["site_crawl"].reenable
    end
  end
end

desc "クローリング処理"
task :site_crawl, ['location', 'request'] do |task, args|
  logic = Logic.new(args[:location].site, @log)# クローリング〜DBへの出力処理
  if args[:location].site == AGODA_CODE # agodaの場合のみ
    logic.crawl_agoda(args[:location], args[:request])
  else
    logic.crawl(args[:location], args[:request])
  end
end

desc "リクエスト管理"
task :request_check do
  if RequestManager.running_request_all.count > 0
    loop do
      running_requests = RequestManager.running_request_all
      sleep 20
      running_requests.each do |request|
        RequestManager.compel_exit(request) if RequestManager.exit?(request)
        RequestManager.error_check(request)
        RequestManager.location_check(request)
      end
    end
  else
    if requests = RequestManager.get_request
      requests.each do |request|
        unless request.checkin_day.nil? && request.checkout_day.nil?#チェックインとチェックアウトのNULLを許可する
          RequestManager.check_date_format(request)# 登録された宿泊日の形式が４桁-2桁-2桁の形式になっているかチェック
          RequestManager.check_start_end_date(request)# チェックイン日がチェックアウト日を超えて登録されていないかどうかのチェック
          RequestManager.check_start_date(request)# 宿泊日開始日が過去の日付でないかどうかのチェック
          RequestManager.check_search_period(request)# 宿泊日数が特定サイトにおいて予約可能な日数かどうかのチェック
          RequestManager.check_total_number_people(request) if request.site_code == '0040'# 一休：宿泊人数が9人以内かチェック
        end
        RequestManager.location_insert(request,@log)#location_masterからlocationsテーブルにリクエスト実行分のレコードをインサート
        RequestManager.request_run(request)#リクエスト開始処理
      end
    end
  end
end
