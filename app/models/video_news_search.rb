class VideoNewsSearch < NewsSearch
  def initialize(options = {})
    super(options)
  end

  def search
    rss_feeds = @rss_feed ? [@rss_feed] : @affiliate.rss_feeds.videos.navigable_only
    @rss_feed = rss_feeds.first if @rss_feed.nil? and rss_feeds and rss_feeds.count == 1
    NewsItem.search_for(@query, rss_feeds, @since, @page)
  end

  protected

  def assign_rss_feed(channel_id)
    @rss_feed = @affiliate.rss_feeds.videos.find_by_id(channel_id.to_i) if channel_id.present?
  end
end