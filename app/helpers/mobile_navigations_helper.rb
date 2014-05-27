module MobileNavigationsHelper
  def renderable_navigations(search)
    is_inactive_search?(search) ? [] : filter_media_navs(search.affiliate)
  end

  def filter_media_navs(affiliate)
    affiliate.navigations.active.reject do |n|
      (n.navigable.is_a?(ImageSearchLabel) && affiliate.flickr_profiles.blank?) ||
      (n.navigable.is_a?(RssFeed) && n.navigable.show_only_media_content?)
    end
  end

  def navigation_heading
    @search.affiliate.left_nav_label.present? ? @search.affiliate.left_nav_label : I18n.t(:search)
  end

  def navigations_and_related_sites(search, search_params, navigations)
    current_navigable = detect_non_default_search_navigable search
    if current_navigable && current_navigable.navigation.is_inactive?
      return standalone_search_navigation search, current_navigable
    end

    if navigations.present? || search.affiliate.connections.present?
      full_navigations(search, search_params, navigations).html_safe
    end
  end

  def standalone_search_navigation(search, navigable)
    html = navigation_item(navigable.name, true) << related_site_links(search)
    navigation_wrapper(html.html_safe, 'in')
  end

  def full_navigations(search, search_params, navigations)
    non_default_search_navigable = detect_non_default_search_navigable search

    html = navigations.present? ? default_search_navigation(search, search_params) : ''
    nav_items = build_navigations_items search, search_params, non_default_search_navigable, navigations
    active_navigation_index = detect_active_navigation_index(search, non_default_search_navigable, navigations)
    related_sites_html = related_site_links search
    build_navigations html, nav_items, active_navigation_index, related_sites_html
  end

  def detect_non_default_search_navigable(search)
    case search
      when is_default_search?(search)
        nil
      when OdieImageSearch
        search.affiliate.image_search_label
      when SiteSearch
        search.document_collection
      when NewsSearch
        search.rss_feed
    end
  end

  def default_search_navigation(search, search_params)
    search_everything_builder search, search_params do |label, is_active, path|
      navigation_item label, is_active, path
    end
  end

  def search_everything_builder(search, search_params)
    search_label = search.affiliate.default_search_label
    params = search_params.slice(:affiliate, :m).
        merge(query: search.query)

    yield search_label, is_default_search?(search), search_path(params)
  end

  def is_default_search?(search)
    search.instance_of? WebSearch
  end

  def build_navigations_items(search, search_params, non_default_search_navigable, navigations)
    navigation_builder search, search_params, non_default_search_navigable, navigations do |navigable_name, is_active, path|
      navigation_item navigable_name, is_active, path
    end
  end

  def navigation_builder(search, search_params, non_default_search_navigable, navigations)
    query = search.query
    navigations.map do |navigation|
      navigable = navigation.navigable
      path =
          case navigable
            when ImageSearchLabel
              path_for_image_search(search_params, query)
            when DocumentCollection
              path_for_document_collection_search(search_params, navigable, query)
            when RssFeed
              path_for_rss_feed_search(search_params, navigable, query)
          end
      is_active = non_default_search_navigable == navigable
      yield navigable.name, is_active, path
    end
  end

  def path_for_image_search(search_params, query)
    image_search_params = search_params.slice(:affiliate).merge(query: query)
    image_search_path image_search_params
  end

  def path_for_document_collection_search(search_params, navigable, query)
    dc_params = navigable_params(search_params, :dc, navigable.id, query,
                                 :affiliate, :m, :sitelimit)
    docs_search_path(dc_params)
  end

  def path_for_rss_feed_search(search_params, navigable, query)
    rss_params = navigable_params(search_params, :channel, navigable.id, query,
                                  :affiliate, :m, :tbs)
    news_search_path(rss_params)
  end

  def navigable_params(search_params, id_sym, id, query, *keys)
    search_params.slice(*keys).merge(id_sym => id, :query => query)
  end

  def navigation_item(title, is_active, path = nil)
    css_class = is_active ? 'active' : nil
    content_tag(:li, nil, class: css_class) do
      link_to_unless is_active, title, path do
        content_tag(:span, title)
      end
    end
  end

  def detect_active_navigation_index(search, non_default_search_navigable, navigations)
    return if is_default_search?(search) || non_default_search_navigable.nil?
    navigations.map(&:navigable).find_index { |n| n == non_default_search_navigable }
  end

  def build_navigations(html, nav_items, active_nav_index, related_sites_html)
    if nav_items.length <= 3
      navigation_wrapper(html.html_safe << nav_items.join("\n").html_safe << related_sites_html,
                         nav_classes(nav_items.length, related_sites_html))
    else
      navigations_with_dropdown(html, nav_items, active_nav_index, related_sites_html)
    end
  end

  def navigation_wrapper(html, nav_class = nil)
    render partial: '/searches/nav_wrapper', locals: { html: html, nav_class: nav_class }
  end

  def nav_classes(nav_items_length, related_sites_html)
    nav_classes = []
    nav_classes << 'has-full-nav-items' if nav_items_length > 2
    nav_classes << 'has-related-sites' if related_sites_html.present?
    nav_classes.join ' '
  end

  def navigations_with_dropdown(html, nav_items, active_nav_index, related_sites_html)
    nav_items_length = nav_items.length
    if active_nav_index and active_nav_index > 1
      active_nav_html = nav_items.slice!(active_nav_index)
      visible_nav_html = nav_items.slice!(0) << "\n" << active_nav_html << "\n"
    else
      visible_nav_html = nav_items.slice!(0, 2).join("\n")
    end
    dropdown_nav_html = nav_items

    html << "\n" << visible_nav_html.html_safe
    html << "\n" << dropdown_navigation_wrapper(dropdown_nav_html.join("\n").html_safe, 'nav-dropdown')
    html << related_sites_html

    navigation_wrapper(html, nav_classes(nav_items_length, related_sites_html))
  end

  def related_site_links(search)
    connections = search.affiliate.connections.includes(:connected_affiliate)
    return if connections.blank?
    return related_site_item(connections.first, search.query) if connections.length == 1

    related_site_items connections, search.query
  end

  def related_site_items(connections, query)
    html = connections.map { |conn| related_site_item(conn, query) }
    dropdown_navigation_wrapper(html.join(' ').html_safe,
                                'related-sites-dropdown',
                                I18n.t(:'searches.related_sites'))
  end

  def dropdown_navigation_wrapper(html, id, show_more_label = I18n.t(:show_more))
    dropdown_wrapper 'searches/dropdown_nav_wrapper', html, id, show_more_label
  end
end