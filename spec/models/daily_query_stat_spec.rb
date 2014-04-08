require 'spec_helper'

describe DailyQueryStat do
  fixtures :daily_query_stats, :affiliates
  before(:each) do
    @valid_attributes = {
      :day => "20090830",
      :query => "government",
      :times => 314,
      :affiliate => Affiliate::USAGOV_AFFILIATE_NAME
    }
  end

  describe 'validations on create' do
    it { should validate_presence_of :day }
    it { should validate_presence_of :query }
    it { should validate_presence_of :times }
    it { should validate_presence_of :affiliate }
    it { should validate_uniqueness_of(:query).scoped_to([:day, :affiliate]) }

    it "should create a new instance given valid attributes" do
      DailyQueryStat.create!(@valid_attributes)
    end

    it "should create a new instance with the default locale if none is specified" do
      @valid_attributes.delete(:locale)
      DailyQueryStat.create(@valid_attributes).locale.should == I18n.default_locale.to_s
    end

    context "when queries have extra internal whitespace and/or external whitespace" do
      before do
        @unsquished_query = '  this query  should be   squished.  '
        @squished_query = 'this query should be squished.'
      end

      it "should remove extra interal whitespace and strip whitespace off the ends on create" do
        DailyQueryStat.create(@valid_attributes.merge(:query => @unsquished_query)).query.should == @squished_query
      end

      it "should remove extra internal whitespace and strip whitespace off the ends on update" do
        daily_query_stat = DailyQueryStat.create(@valid_attributes.merge(:query => 'something'))
        daily_query_stat.id.should_not be_nil
        daily_query_stat.update_attributes(:query => @unsquished_query)
        daily_query_stat.query.should == @squished_query
      end
    end
  end

  describe ".low_ctr_queries(affiliate_name)" do
    before do
      usagov = Affiliate::USAGOV_AFFILIATE_NAME
      DailyQueryStat.create!(:day => Date.current - 2, :query => "low ctr query", :times => 101, :affiliate => usagov)
      DailyQueryStat.create!(:day => Date.current - 1, :query => "low ctr query", :times => 201, :affiliate => usagov)
      DailyQueryStat.create!(:day => Date.current - 1, :query => "another low ctr query", :times => 201, :affiliate => usagov)
      DailyQueryStat.create!(:day => Date.current - 1, :query => "high ctr query", :times => 100, :affiliate => usagov)
      DailyQueryStat.create!(:day => Date.current - 1, :query => "zero ctr", :times => 21, :affiliate => usagov)
      DailyQueryStat.create!(:day => Date.current - 1, :query => "zero ctr but too small", :times => 9, :affiliate => usagov)
      DailyQueryStat.create!(:day => Date.current - 1, :query => "what is this?", :times => 201, :affiliate => usagov)
      DailyQueryStat.create!(:day => Date.current - 1, :query => "got no results", :times => 201, :affiliate => usagov)
      DailyQueryNoresultsStat.create!(:day => Date.current - 1, :query => "got no results", :times => 201, :affiliate => usagov)
      QueriesClicksStat.create!(:affiliate => usagov, :query => "high ctr query", :day => Date.current - 1,
                                :url => "http://www.gov.gov/1", :times => 20)
      QueriesClicksStat.create!(:affiliate => usagov, :query => "low ctr query", :day => Date.current - 1,
                                :url => "http://www.gov.gov/1", :times => 14)
      QueriesClicksStat.create!(:affiliate => usagov, :query => "another low ctr query", :day => Date.current - 1,
                                :url => "http://www.gov.gov/2", :times => 17)
    end

    it "should filter out queries that are too long, have unusual punctuation, or are low volume" do
      lows = DailyQueryStat.low_ctr_queries(Affiliate::USAGOV_AFFILIATE_NAME)
      lows.size.should == 3
      lows[0].should == ["zero ctr", 0]
      lows[1].should == ["low ctr query", 4]
      lows[2].should == ["another low ctr query", 8]
    end
  end

  describe ".trending_queries(affiliate_name)" do
    before do
      usagov = Affiliate::USAGOV_AFFILIATE_NAME
      DailyQueryStat.create!(:day => Date.current - 2, :query => "trending", :times => 9, :affiliate => "another")
      DailyQueryStat.create!(:day => Date.current - 1, :query => "trending", :times => 900, :affiliate => "another")
      DailyQueryStat.create!(:day => Date.current - 2, :query => "u.s. trending up-wards", :times => 9, :affiliate => usagov)
      DailyQueryStat.create!(:day => Date.current - 1, :query => "u.s. trending up-wards", :times => 900, :affiliate => usagov)
      DailyQueryStat.create!(:day => Date.current - 2, :query => "too long"*4, :times => 9, :affiliate => usagov)
      DailyQueryStat.create!(:day => Date.current - 1, :query => "too long"*4, :times => 900, :affiliate => usagov)
      DailyQueryStat.create!(:day => Date.current - 2, :query => 'probably "fake"', :times => 9, :affiliate => usagov)
      DailyQueryStat.create!(:day => Date.current - 1, :query => 'probably "fake"', :times => 900, :affiliate => usagov)
    end

    it "should filter out queries that are too long and/or have unusual punctuation" do
      tqs = DailyQueryStat.trending_queries(Affiliate::USAGOV_AFFILIATE_NAME)
      tqs.size.should == 1
      tqs.first.should == "u.s. trending up-wards"
    end
  end

  describe '.most_popular_terms' do
    context "when the table is populated" do
      before do
        usagov = Affiliate::USAGOV_AFFILIATE_NAME
        DailyQueryStat.create!(:day => 12.days.ago.to_date, :query => "older most popular", :times => 9, :affiliate => usagov)
        DailyQueryStat.create!(:day => 12.days.ago.to_date, :query => "recent day most popular", :times => 2, :affiliate => usagov)
        DailyQueryStat.create!(:day => 11.days.ago.to_date, :query => "older most popular", :times => 1, :affiliate => usagov)
        DailyQueryStat.create!(:day => 11.days.ago.to_date, :query => "recent day most popular", :times => 4, :affiliate => usagov)
        DailyQueryStat.create!(:day => 11.days.ago.to_date, :query => "sparse term", :times => 1, :affiliate => usagov)
      end

      let(:recent_date) { DailyQueryStat.most_recent_populated_date(Affiliate::USAGOV_AFFILIATE_NAME) }

      it "should calculate popularity sums based on the start/end date, ignoring terms with a frequency of less than 4" do
        yday = DailyQueryStat.most_popular_terms(Affiliate::USAGOV_AFFILIATE_NAME, recent_date, recent_date, 1)
        yday.first.query.should == "recent day most popular"
        yday.first.times.should == 4
        twodaysago = DailyQueryStat.most_popular_terms(Affiliate::USAGOV_AFFILIATE_NAME, recent_date-1.day, recent_date, 2)
        twodaysago.first.query.should == "older most popular"
        twodaysago.first.times.should == 10
      end

      it "should use the num_results parameter to determine result set size" do
        DailyQueryStat.most_popular_terms(Affiliate::USAGOV_AFFILIATE_NAME, recent_date, recent_date, 1).size.should == 1
      end

      context "when data exists for more than the default affiliate" do
        before do
          DailyQueryStat.create!(:day => 12.days.ago.to_date, :query => "older most popular", :times => 10, :affiliate => "other_affiliate")
          DailyQueryStat.create!(:day => 12.days.ago.to_date, :query => "recent day most popular", :times => 3, :affiliate => "other_affiliate")
          DailyQueryStat.create!(:day => 11.days.ago.to_date, :query => "older most popular", :times => 2, :affiliate => "other_affiliate")
          DailyQueryStat.create!(:day => 11.days.ago.to_date, :query => "recent day most popular", :times => 5, :affiliate => "other_affiliate")
        end

        it "should use the affiliate parameter if set to scope the results" do
          yday = DailyQueryStat.most_popular_terms("other_affiliate", recent_date, recent_date, 10)
          yday.first.query.should == "recent day most popular"
          yday.first.times.should == 5
          twodaysago = DailyQueryStat.most_popular_terms("other_affiliate", recent_date-2.days, recent_date, 10)
          twodaysago.first.query.should == "older most popular"
          twodaysago.first.times.should == 12
        end
      end

      context "when a very small amount of affiliate data exists" do
        before do
          DailyQueryStat.create!(:day => Date.yesterday, :query => "sparse term", :times => 1, :affiliate => "tiny_affiliate")
        end

        it "should return those results for affiliates" do
          mrd = DailyQueryStat.most_recent_populated_date("tiny_affiliate")
          most_popular_terms = DailyQueryStat.most_popular_terms("tiny_affiliate", mrd, mrd, 10)
          most_popular_terms.class.should == Array
          most_popular_terms.size.should == 1
        end
      end
    end

    context "when the table has no data for the time period specified" do
      it "should return an error string that no queries matched" do
        DailyQueryStat.most_popular_terms(Affiliate::USAGOV_AFFILIATE_NAME, Date.tomorrow, Date.tomorrow).should == "Not enough historic data to compute most popular"
      end
    end
  end

  describe ".most_recent_populated_date" do
    it "should return the most recent date for an affiliate if an affiliate is passed in" do
      DailyQueryStat.should_receive(:maximum).with(:day, :conditions => ['affiliate = ?', 'nps.gov'])
      DailyQueryStat.most_recent_populated_date('nps.gov')
    end
  end

  describe 'sum_for_affiliate_between_dates' do
    it 'returns sum for the given affiliate name between specified dates' do
      usagov = Affiliate::USAGOV_AFFILIATE_NAME
      yesterday = Date.current.yesterday
      last_week = Date.current.prev_week
      where_clause = mock('where')
      DailyQueryStat.should_receive(:where).
          with('affiliate = ? AND day BETWEEN ? AND ?', usagov, yesterday, last_week).
          and_return(where_clause)
      where_clause.should_receive(:sum).with(:times)

      DailyQueryStat.sum_for_affiliate_between_dates(usagov, yesterday, last_week)
    end
  end
end
