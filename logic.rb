require_relative 'common'

class Logic
  def initialize(site, logger)
    @site = site
    @log = logger
    @crawler = BaseCrawler.factory(@site)
    @parser = BaseParser.factory(@site)
    @formatter = Formatter.new(@log)
  end

  def crawl(location,request)# main処理：クローリング〜DB格納
    page_num = 1
    begin
      hash_rows_arr = []
      crawl_params = location.crawl_params
      loop do#対象が複数ページある場合、ループで取得
        doc = @crawler.get_doc(request, page_num, crawl_params)
        hash_rows_arr.concat(@parser.parse_plan(doc, request, location))
        @crawler.next_page?(doc) ? page_num += 1 : break#次のページがあれば１ページ足して次のページへ
      end
      location.update(status:2)
      db_rows = @parser.filter_lowest_plan(hash_rows_arr)#値段順のソート、ユニーク化を実施
      @formatter.save_db(db_rows)# DBに値をインサート
    rescue => e
      area_error(e,location)# 件数取得ゼロ時、もしくはエリア内のクローリング中エラーの処理
    end
  end

  def crawl_agoda(location, request) # agoda向けmain処理：クローリング〜DB格納
    # agodaはnext_page?, filter_lowest_planの必要なし
    # メモリ食いすぎるので毎回save_dbする
    @crawler.crawl_and_save_db(@parser, request, location, @formatter)
    location.update(status: 2)
  rescue => e
    area_error(e, location)# 件数取得ゼロ時、もしくはエリア内のクローリング中エラーの処理
  end

  def area_error(e,location)# エリア毎の取得エラー時の処理
    error_row = {}
    if e.message == '件数が取得できませんでした' then
      if location.site == RAKUTEN_CODE || location.site == JALAN_CODE
        if location.is_count_error_flag == 1
          location.update(status: 3, result: 'ERROR100', message: 'クロール中に情報の取得に失敗しました。')
        else
          location.update(status: 2, result: 'ERROR200', message: '条件に該当する検索結果はありませんでした。検索条件を変更し、再度検索をお願いします。')
        end
      else
        location.update(status: 2, result: 'ERROR200', message: '条件に該当する検索結果はありませんでした。検索条件を変更し、再度検索をお願いします。')
      end
    else
      error_stack = e.backtrace.map{|e| e.gsub(/["'`]/, '')}.pretty_inspect
      error_message =  "## ジョブ異常終了！！ ##\n" + e.message + "\n" + error_stack
      Transporter.mail(location[:area], error_message)
      location.update(status:3, result: 'ERROR100', message: 'クロール中に情報の取得に失敗しました。')
    end
  end
end
