class DailySearchModuleStat < ActiveRecord::Base
  require "ostruct"
  validates_presence_of :day, :locale, :affiliate_name, :vertical, :module_tag, :clicks, :impressions
  validates_uniqueness_of :module_tag, :scope => [:day, :affiliate_name, :locale, :vertical]
  belongs_to :search_module, :primary_key => "tag", :foreign_key => "module_tag", :class_name => "SearchModule"
  before_validation :set_locale
  
  SPARKLINE_MONTHS_TO_SHOW = 2

  def self.most_recent_populated_date
    maximum(:day)
  end

  def self.module_stats_for_daterange(daterange, affiliate_name = nil, vertical = nil)
    conditions = {:day => daterange}
    conditions.merge!(:affiliate_name => affiliate_name) if affiliate_name
    conditions.merge!(:vertical => vertical) if vertical
    sparkline_range = daterange.last-SPARKLINE_MONTHS_TO_SHOW.month..daterange.last
    results = select('module_tag, display_name, SUM(clicks) AS clicks, SUM(impressions) AS impressions').where(conditions).group(:module_tag).order("clicks DESC").joins(:search_module)
    total_clicks, total_impressions = 0, 0
    ctr_query = 'day, 100.0*sum(clicks)/sum(impressions) ctr'
    stats = results.collect do |stat|
      historical_ctr = select(ctr_query).where(conditions.merge(:module_tag=>stat.module_tag, :day=> sparkline_range)).group(:day).collect { |r| r.ctr }
      total_clicks += stat.clicks
      total_impressions += stat.impressions
      OpenStruct.new(:display_name => stat.display_name, :clicks => stat.clicks, :impressions => stat.impressions, :clickthru_ratio => 100.0 * stat.clicks / stat.impressions, :historical_ctr => historical_ctr)
    end.compact
    unless stats.empty?
      historical_ctr = select(ctr_query).where(conditions.merge(:day=> sparkline_range)).group(:day).collect { |r| r.ctr }
      stats << OpenStruct.new(:display_name => "Total", :clicks => total_clicks, :impressions => total_impressions,
                              :clickthru_ratio => 100.0 * total_clicks / total_impressions, :historical_ctr => historical_ctr)
    end
    stats
  end
  
  private
  
  def set_locale
    self.locale = (Affiliate.find_by_name(self.affiliate_name).locale rescue "en") unless self.locale
  end
end