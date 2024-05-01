# frozen_string_literal: true

class SitemapIndexerJob < ApplicationJob
  queue_as :sitemap
  unique :until_performed

  def perform(sitemap_url:, domain:)
    SitemapIndexer.new(sitemap_url: , domain: ).index
  end
end
