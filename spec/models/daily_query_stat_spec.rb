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

  describe ".trending_queries(affiliate_name)" do
    before do
      DailyQueryStat.delete_all
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
        DailyQueryStat.delete_all
        DailyQueryStat.create!(:day => 12.days.ago.to_date, :query => "older most popular", :times => 9, :affiliate => Affiliate::USAGOV_AFFILIATE_NAME)
        DailyQueryStat.create!(:day => 12.days.ago.to_date, :query => "recent day most popular", :times => 2, :affiliate => Affiliate::USAGOV_AFFILIATE_NAME)
        DailyQueryStat.create!(:day => 11.days.ago.to_date, :query => "older most popular", :times => 1, :affiliate => Affiliate::USAGOV_AFFILIATE_NAME)
        DailyQueryStat.create!(:day => 11.days.ago.to_date, :query => "recent day most popular", :times => 4, :affiliate => Affiliate::USAGOV_AFFILIATE_NAME)
        DailyQueryStat.create!(:day => 11.days.ago.to_date, :query => "sparse term", :times => 1, :affiliate => Affiliate::USAGOV_AFFILIATE_NAME)
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

  describe "#most_recent_populated_date" do
    it "should return the most recent date for an affiliate if an affiliate is passed in" do
      DailyQueryStat.should_receive(:maximum).with(:day, :conditions => ['affiliate = ?', 'nps.gov'])
      DailyQueryStat.most_recent_populated_date('nps.gov')
    end
  end

  describe "#collect_query" do
    let(:start_date) do
      Date.yesterday.advance(:months => -1)
    end

    it "should filter results using affiliate_name and query" do
      DailyQueryStat.should_receive(:generic_collection).with(['day >= ? AND query = ?', start_date, 'foo'])
      DailyQueryStat.collect_query('foo', start_date)
    end
  end

  describe "#collect_affiliate_query" do
    let(:start_date) do
      Date.yesterday.advance(:months => -1)
    end

    it "should filter results using affiliate_name and query" do
      DailyQueryStat.should_receive(:generic_collection).with(['day >= ? AND affiliate = ? AND query = ?', start_date, 'aff', 'foo'])
      DailyQueryStat.collect_affiliate_query('foo', 'aff', start_date)
    end
  end

  describe "#reindex_day(day)" do
    before do
      ResqueSpec.reset!
      DailyQueryStat.delete_all
      DailyQueryStat.create!(:day => "20110830", :query => "government", :times => 314, :affiliate => Affiliate::USAGOV_AFFILIATE_NAME)
      DailyQueryStat.create!(:day => "20110830", :query => "government", :times => 314, :affiliate => affiliates(:power_affiliate).name)
    end

    it "should enqueue reindexing for each trafficked affiliate for the day" do
      DailyQueryStat.reindex_day("20110830")
      DailyQueryStat.should have_queued("20110830", Affiliate::USAGOV_AFFILIATE_NAME)
      DailyQueryStat.should have_queued("20110830", affiliates(:power_affiliate).name)
    end
  end

  describe "#perform(day_string, affiliate_name)" do
    before do
      DailyQueryStat.delete_all
      DailyQueryStat.create!(:day => "20110830", :query => "government", :times => 314, :affiliate => Affiliate::USAGOV_AFFILIATE_NAME)
      @sample = DailyQueryStat.create!(:day => "20110830", :query => "government", :times => 314, :affiliate => affiliates(:power_affiliate).name)
    end

    it "should bulk remove the day's records from Solr for each affiliate and then index from the DB all the affiliate's records for a given day" do
      DailyQueryStat.should_receive(:bulk_remove_solr_records_for_day_and_affiliate).with(@sample.day, @sample.affiliate)
      Sunspot.should_receive(:index).with([@sample])
      DailyQueryStat.perform(@sample.day.to_s, @sample.affiliate)
    end
  end

  describe "#bulk_remove_solr_records_for_day_and_affiliate(day, affiliate_name)" do
    before do
      DailyQueryStat.delete_all
      @first = DailyQueryStat.create!(:day => "20110828", :query => "government", :times => 314, :affiliate => Affiliate::USAGOV_AFFILIATE_NAME)
      DailyQueryStat.create!(:day => "20110829", :query => "government", :times => 314, :affiliate => Affiliate::USAGOV_AFFILIATE_NAME)
      @other = DailyQueryStat.create!(:day => "20110829", :query => "government", :times => 314, :affiliate => affiliates(:power_affiliate).name)
      DailyQueryStat.create!(:day => "20110829", :query => "government loan", :times => 314, :affiliate => Affiliate::USAGOV_AFFILIATE_NAME)
      @last = DailyQueryStat.create!(:day => "20110830", :query => "government", :times => 314, :affiliate => Affiliate::USAGOV_AFFILIATE_NAME)
      DailyQueryStat.reindex
      Sunspot.commit
    end

    it "should remove records from index for specified day and affiliate" do
      DailyQueryStat.bulk_remove_solr_records_for_day_and_affiliate(Date.parse("20110829"), Affiliate::USAGOV_AFFILIATE_NAME)
      Sunspot.commit
      DailyQueryStat.search_for("government", Affiliate::USAGOV_AFFILIATE_NAME, Date.parse("20110828")).should == [@first.id, @last.id]
      DailyQueryStat.search_for("government", affiliates(:power_affiliate).name, Date.parse("20110828"), Date.parse("20110901")).should == [@other.id]
    end
  end
end