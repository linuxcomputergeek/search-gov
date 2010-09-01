require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe DailyUsageStat do
  before(:each) do
    @valid_attributes = {
      :day => Date.today,
      :profile => "value for profile",
      :total_queries => 1,
      :total_page_views => 1,
      :total_unique_visitors => 1    
    }
  end
  
  describe "validations on create" do
    before do
      DailyUsageStat.create!(@valid_attributes)
    end
          
    should_validate_presence_of :day, :profile, :affiliate
    should_validate_uniqueness_of :day, :scope => [:profile, :affiliate]  
  end

  context "When populating data for yesterday" do
    before do
      @yesterday = Date.parse('20100302')
      Query.delete_all
      # English queries
      query_params = {
        :ipaddr => '127.0.0.1',
        :query => 'test',
        :affiliate => 'usasearch.gov',
        :timestamp => Time.parse("00:01", @yesterday),
        :locale => 'en', 
        :agent => 'Mozilla/5.0',
        :is_bot => false,
        :is_contextual => false
      }
      # regular queries    
      5.times do |index|
        Query.create(query_params.merge(:timestamp => Time.parse("00:01", @yesterday) + index.hours))
        Query.create(query_params.merge(:timestamp => Time.parse("00:01", @yesterday + 1.day) + index.hours))
      end
      # Spanish queries
      5.times do |index|
        Query.create(query_params.merge(:timestamp => Time.parse("00:01", @yesterday) + index.hours, :locale => 'es'))
        Query.create(query_params.merge(:timestamp => Time.parse("00:01", @yesterday + 1.day) + index.hours, :locale => 'es'))
      end
      # Affiliate queries
      5.times do |index|
        Query.create(query_params.merge(:timestamp => Time.parse("00:01", @yesterday) + index.hours, :affiliate => 'test.gov'))
        Query.create(query_params.merge(:timestamp => Time.parse("00:01", @yesterday + 1.day) + index.hours, :affiliate => 'test.gov'))
      end
      # Affiliate queries with Spanish locale
      5.times do |index|        
        Query.create(query_params.merge(:timestamp => Time.parse("00:01", @yesterday) + index.hours, :affiliate => 'test.gov', :locale => 'es'))
        Query.create(query_params.merge(:timestamp => Time.parse("00:01", @yesterday + 1.day) + index.hours, :affiliate => 'test.gov', :locale => 'es'))
      end
      # records with is_bot set to true; these should be ignored
      5.times do |index|
        Query.create(query_params.merge(:timestamp => Time.parse("00:01", @yesterday) + index.hours, :is_bot => true))
        Query.create(query_params.merge(:timestamp => Time.parse("00:01", @yesterday + 1.day) + index.hours, :is_bot => true))
      end
      # records with nil agent and is_bot
      5.times do |index|
        Query.create(query_params.merge(:timestamp => Time.parse("00:01", @yesterday) + index.hours, :agent => nil, :is_bot => nil))
        Query.create(query_params.merge(:timestamp => Time.parse("00:01", @yesterday + 1.day) + index.hours, :agent => nil, :is_bot => nil))
      end      
      # contextual queries; should not be included in stats
      5.times do |index|
        Query.create(query_params.merge(:timestamp => Time.parse("00:01", @yesterday) + index.hours, :is_contextual => true))
        Query.create(query_params.merge(:timestamp => Time.parse("00:01", @yesterday + 1.day) + index.hours, :is_contextual => true))
      end
    end  

    context "when the Profile is English" do
      before do
        @daily_usage_stat = DailyUsageStat.new(:day => @yesterday, :profile => 'English')
        response_body = "{\"definition\":{\"accountID\":19421,\"profileID\":\"TAaTt56X0j6\",\"ID\":\"TAaTt56X0j6\",\"name\":\"Search English\",\"language\":null,\"type\":\"profilestats\",\"dimension\":{\"ID\":null,\"name\":\"Date\",\"type\":\"period\",\"Range\":{\"startperiod\":\"2010m03d02\",\"trendperiods\":1},\"Properties\":null,\"SubDimension\":null},\"measures\":null},\"data\":{\"03/02/2010\":{\"Attributes\":{\"Average Visit Duration\":\"00:04:34\",\"Median Visit Duration\":\"00:00:59\",\"Visit Duration Seconds\":\"3,410,681\",\"Most Active Date\":\"-\",\"Most Active Day of the Week\":\"-\",\"Most Active Hour of the Day\":\"14:00-14:59\",\"Least Active Date\":\"-\",\"Last Realtime Analysis Date\":\"2010-03-09 23:39:59\",\"Last Analysis Date\":\"2010-03-09 19:19:48\"},\"measures\":{\"Page Views\":84124.0,\"Visits\":16358.0,\"Visits from Your Country: United States (US)\":88.45,\"International Visits\":11.55,\"Visits of Unknown Origin\":0.0,\"Average Page Views per Day\":84124.0,\"Page Views per Visit\":5.14,\"Average Visits per Day\":16358.0,\"Average Visits per Visitor\":1.05,\"Visitors\":15633.0,\"Visitors Who Visited Once\":15065.0,\"Visitors Who Visited More Than Once\":568.0,\"Visit Duration Seconds Count\":12412.0,\"Total Hits\":84124.0,\"Successful Hits\":84124.0,\"Successful Hits (as Percent)\":100.0,\"Failed Hits\":0.0,\"Failed Hits (as Percent)\":0.0,\"Cached Hits\":0.0,\"Cached Hits (as Percent)\":0.0,\"Number of Hits on Most Active Date\":null,\"Average Number of Visits per day on Weekdays\":16358.0,\"Average Number of Hits per day on Weekdays\":84124.0,\"Total Hits Weekend\":null,\"Average Number of Visits per Weekend\":0.0,\"Average Number of Hits per Weekend\":0.0},\"SubRows\":null}}}"
        @daily_usage_stat.stub!(:get_profile_data).and_return response_body
      end
    
      it "should populate the proper data for each of the daily metrics" do
        @daily_usage_stat.populate_data
        @daily_usage_stat.total_queries.should == 10
        @daily_usage_stat.total_page_views.should == 84124
        @daily_usage_stat.total_unique_visitors.should == 15633
      end
    
      it "should sum up all the English queries from the past day ignoring queries from bots" do
        Query.should_receive(:count).with(:all, :conditions => ["timestamp between ? and ? AND locale=? AND affiliate=? AND (is_bot=false OR ISNULL(is_bot)) AND is_contextual=false", Time.parse('00:00', @yesterday), Time.parse('23:59:59', @yesterday), "en", "usasearch.gov"])
        @daily_usage_stat.populate_data
      end
    end
    
    context "when the Profile is Spanish" do
      before do
        @daily_usage_stat = DailyUsageStat.new(:day => @yesterday, :profile => 'Spanish')
        response_body = "{\"definition\":{\"accountID\":19421,\"profileID\":\"I2JrcxgX0j6\",\"ID\":\"I2JrcxgX0j6\",\"name\":\"Search Spanish\",\"language\":null,\"type\":\"profilestats\",\"dimension\":{\"ID\":null,\"name\":\"Date\",\"type\":\"period\",\"Range\":{\"startperiod\":\"2010m03d02\",\"trendperiods\":1},\"Properties\":null,\"SubDimension\":null},\"measures\":null},\"data\":{\"03/02/2010\":{\"Attributes\":{\"Average Visit Duration\":\"00:04:24\",\"Median Visit Duration\":\"00:01:11\",\"Visit Duration Seconds\":\"75,819\",\"Most Active Date\":\"-\",\"Most Active Day of the Week\":\"-\",\"Most Active Hour of the Day\":\"20:00-20:59\",\"Least Active Date\":\"-\",\"Last Realtime Analysis Date\":\"2010-03-10 08:39:59\",\"Last Analysis Date\":\"2010-03-10 07:21:59\"},\"measures\":{\"Page Views\":1970.0,\"Visits\":391.0,\"Visits from Your Country: United States (US)\":56.27,\"International Visits\":43.73,\"Visits of Unknown Origin\":0.0,\"Average Page Views per Day\":1970.0,\"Page Views per Visit\":5.04,\"Average Visits per Day\":391.0,\"Average Visits per Visitor\":1.02,\"Visitors\":383.0,\"Visitors Who Visited Once\":375.0,\"Visitors Who Visited More Than Once\":8.0,\"Visit Duration Seconds Count\":287.0,\"Total Hits\":1970.0,\"Successful Hits\":1970.0,\"Successful Hits (as Percent)\":100.0,\"Failed Hits\":0.0,\"Failed Hits (as Percent)\":0.0,\"Cached Hits\":0.0,\"Cached Hits (as Percent)\":0.0,\"Number of Hits on Most Active Date\":null,\"Average Number of Visits per day on Weekdays\":391.0,\"Average Number of Hits per day on Weekdays\":1970.0,\"Total Hits Weekend\":null,\"Average Number of Visits per Weekend\":0.0,\"Average Number of Hits per Weekend\":0.0},\"SubRows\":null}}}"
        @daily_usage_stat.stub!(:get_profile_data).and_return response_body
      end

      it "should populate the proper data for each of the daily metrics" do
        @daily_usage_stat.populate_data
        @daily_usage_stat.total_queries.should == 5
        @daily_usage_stat.total_page_views.should == 1970
        @daily_usage_stat.total_unique_visitors.should == 383
      end

      it "should sum up all the Spanish queries from the past day, ignore queries from bots" do
        Query.should_receive(:count).with(:all, :conditions => ["timestamp between ? and ? AND locale=? AND affiliate=? AND (is_bot=false OR ISNULL(is_bot)) AND is_contextual=false", Time.parse('00:00', @yesterday), Time.parse('23:59:59', @yesterday), "es", "usasearch.gov"])
        @daily_usage_stat.populate_data
      end
    end
    
    context "when the Profile is Affiliates" do
      before do
        @daily_usage_stat = DailyUsageStat.new(:day => @yesterday, :profile => 'Affiliates')
        response_body = "{\"definition\":{\"accountID\":19421,\"profileID\":\"ivO5EkIX0j6\",\"ID\":\"ivO5EkIX0j6\",\"name\":\"Search Affiliates\",\"language\":null,\"type\":\"profilestats\",\"dimension\":{\"ID\":null,\"name\":\"Date\",\"type\":\"period\",\"Range\":{\"startperiod\":\"2010m03d02\",\"trendperiods\":1},\"Properties\":null,\"SubDimension\":null},\"measures\":null},\"data\":{\"03/02/2010\":{\"Attributes\":{\"Average Visit Duration\":\"00:03:16\",\"Median Visit Duration\":\"00:00:37\",\"Visit Duration Seconds\":\"9,458,667\",\"Most Active Date\":\"-\",\"Most Active Day of the Week\":\"-\",\"Most Active Hour of the Day\":\"14:00-14:59\",\"Least Active Date\":\"-\",\"Last Realtime Analysis Date\":\"2010-03-10 08:39:59\",\"Last Analysis Date\":\"2010-03-10 07:34:43\"},\"measures\":{\"Page Views\":260563.0,\"Visits\":65413.0,\"Visits from Your Country: United States (US)\":89.38,\"International Visits\":10.62,\"Visits of Unknown Origin\":0.0,\"Average Page Views per Day\":260563.0,\"Page Views per Visit\":3.98,\"Average Visits per Day\":65413.0,\"Average Visits per Visitor\":1.04,\"Visitors\":63057.0,\"Visitors Who Visited Once\":61098.0,\"Visitors Who Visited More Than Once\":1959.0,\"Visit Duration Seconds Count\":48171.0,\"Total Hits\":260563.0,\"Successful Hits\":260563.0,\"Successful Hits (as Percent)\":100.0,\"Failed Hits\":0.0,\"Failed Hits (as Percent)\":0.0,\"Cached Hits\":0.0,\"Cached Hits (as Percent)\":0.0,\"Number of Hits on Most Active Date\":null,\"Average Number of Visits per day on Weekdays\":65413.0,\"Average Number of Hits per day on Weekdays\":260563.0,\"Total Hits Weekend\":null,\"Average Number of Visits per Weekend\":0.0,\"Average Number of Hits per Weekend\":0.0},\"SubRows\":null}}}"
        @daily_usage_stat.stub!(:get_profile_data).and_return response_body
      end
      
      it "should populate the proper data for each of the daily metrics" do
        @daily_usage_stat.populate_data
        @daily_usage_stat.total_queries.should == 10
        @daily_usage_stat.total_page_views.should == 260563
        @daily_usage_stat.total_unique_visitors.should == 63057
      end

      it "should sum up all the Affiliates queries from the past day, regardless of locale, ignoring any records marked as bots" do
        Query.should_receive(:count).with(:all, :conditions => ["timestamp between ? and ? AND affiliate <> ? AND (is_bot=false OR ISNULL(is_bot)) AND is_contextual=false", Time.parse('00:00', @yesterday), Time.parse('23:59:59', @yesterday), "usasearch.gov"])
        @daily_usage_stat.populate_data
      end
    end

    context "when the populating data for a specific affiliate" do
      before do
        @daily_usage_stat = DailyUsageStat.new(:day => @yesterday, :profile => 'Affiliates', :affiliate => 'test.gov')
      end

      it "should populate the proper data for each of the daily metrics for affiliates" do
        @daily_usage_stat.populate_data
        @daily_usage_stat.total_queries.should == 10
        @daily_usage_stat.total_page_views.should be_nil
        @daily_usage_stat.total_unique_visitors.should be_nil
      end

      it "should sum up all the queries from the past day regardless of locale, ignoring bots, for the affiliate specified" do
        Query.should_receive(:count).with(:all, :conditions => ["timestamp between ? and ? AND affiliate = ? AND (is_bot=false OR ISNULL(is_bot)) AND is_contextual=false", Time.parse('00:00', @yesterday), Time.parse('23:59:59', @yesterday), 'test.gov'])
        @daily_usage_stat.populate_data
      end
    end
    
    after do
      DailyUsageStat.delete_all
      Query.delete_all
    end
  end
   
  context "When compiling data for a given month" do
    before do
      @year = 2010
      @month = 03
    end

    it "should sum up all the DailyUsageStat values for the given month" do
      DailyUsageStat::PROFILE_NAMES.each do |profile_name|
        DailyUsageStat.should_receive(:total_monthly_queries).with(@year, @month, profile_name, 'usasearch.gov').exactly(1).times
        DailyUsageStat.should_receive(:total_monthly_page_views).with(@year, @month, profile_name, 'usasearch.gov').exactly(1).times
        DailyUsageStat.should_receive(:total_monthly_unique_visitors).with(@year, @month, profile_name, 'usasearch.gov').exactly(1).times
      end
      DailyUsageStat.monthly_totals(@year, @month)
    end
  end

  context "When retrieving data from Webtrends via the Webtrends REST API" do
    before do
      @response_body = "{\"definition\":{\"accountID\":19421,\"profileID\":\"TAaTt56X0j6\",\"ID\":\"TAaTt56X0j6\",\"name\":\"Search English\",\"language\":null,\"type\":\"profilestats\",\"dimension\":{\"ID\":null,\"name\":\"Date\",\"type\":\"period\",\"Range\":{\"startperiod\":\"2010m03d02\",\"trendperiods\":1},\"Properties\":null,\"SubDimension\":null},\"measures\":null},\"data\":{\"03/02/2010\":{\"Attributes\":{\"Average Visit Duration\":\"00:04:34\",\"Median Visit Duration\":\"00:00:59\",\"Visit Duration Seconds\":\"3,410,681\",\"Most Active Date\":\"-\",\"Most Active Day of the Week\":\"-\",\"Most Active Hour of the Day\":\"14:00-14:59\",\"Least Active Date\":\"-\",\"Last Realtime Analysis Date\":\"2010-03-09 23:39:59\",\"Last Analysis Date\":\"2010-03-09 19:19:48\"},\"measures\":{\"Page Views\":84124.0,\"Visits\":16358.0,\"Visits from Your Country: United States (US)\":88.45,\"International Visits\":11.55,\"Visits of Unknown Origin\":0.0,\"Average Page Views per Day\":84124.0,\"Page Views per Visit\":5.14,\"Average Visits per Day\":16358.0,\"Average Visits per Visitor\":1.05,\"Visitors\":15633.0,\"Visitors Who Visited Once\":15065.0,\"Visitors Who Visited More Than Once\":568.0,\"Visit Duration Seconds Count\":12412.0,\"Total Hits\":84124.0,\"Successful Hits\":84124.0,\"Successful Hits (as Percent)\":100.0,\"Failed Hits\":0.0,\"Failed Hits (as Percent)\":0.0,\"Cached Hits\":0.0,\"Cached Hits (as Percent)\":0.0,\"Number of Hits on Most Active Date\":null,\"Average Number of Visits per day on Weekdays\":16358.0,\"Average Number of Hits per day on Weekdays\":84124.0,\"Total Hits Weekend\":null,\"Average Number of Visits per Weekend\":0.0,\"Average Number of Hits per Weekend\":0.0},\"SubRows\":null}}}"
    end

    context "on success" do
      before do
        @http = Net::HTTP.new(DailyUsageStat::WEBTRENDS_HOSTNAME, Net::HTTP.http_default_port)
        @response = Net::HTTPOK.new(200, 1.1, 'OK')
        @response.stub!(:body).and_return @response_body
        @http.stub!(:request).and_return @response
        Net::HTTP.stub!(:new).and_return @http
      end

      it "should return a valid response on success" do
        @daily_usage_stat = DailyUsageStat.new(:day => Date.parse('2010-03-02'), :profile => 'English')
        response = @daily_usage_stat.get_profile_data
        response.should == @response_body
      end
    end

    context "on error" do
      before do
        @http = Net::HTTP.new(DailyUsageStat::WEBTRENDS_HOSTNAME, Net::HTTP.http_default_port)
        @response = Net::HTTPClientError.new(401, 1.1, 'Forbidden')
        @response.stub!(:error!).and_return Net::HTTPForbidden
        @http.stub!(:request).and_return @response
        Net::HTTP.stub!(:new).and_return @http
      end

      it "should return the error" do
        @daily_usage_stat = DailyUsageStat.new(:day => Date.parse('2010-03-02'), :profile => 'English')
        response = @daily_usage_stat.get_profile_data
        response.should == Net::HTTPForbidden
      end
    end
  end

end
