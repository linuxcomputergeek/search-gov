class WidgetsController < ApplicationController
  def top_searches
    @active_top_searches = TopSearch.find_active_entries
  end

  def trending_searches
    @active_top_searches = TopSearch.find_active_entries
  end
end

