function clk(a, b, c, d, e, f, g, h) {
  if (document.images) {
    var img = new Image;
    img.src = ['/clicked?','u=',encodeURIComponent(b),'&q=',escape(a),'&p=',c,'&a=',d,'&s=',e,'&t=',f,'&v=',g,'&l=',h].join('');
  }
  return true;
}

function getParameterByName( name )
{
  name = name.replace(/[\[]/,"\\\[").replace(/[\]]/,"\\\]");
  var regexS = "[\\?&]"+name+"=([^&#]*)";
  var regex = new RegExp( regexS );
  var results = regex.exec( window.location.href );
  if( results == null )
    return "";
  else
    return decodeURIComponent(results[1].replace(/\+/g, " "));
}

(function($) {
  $.fn.share = function() {
    var shareLinks = this;
    $.getScript("https://s9.addthis.com/js/widget.php?v=10", function() {
      shareLinks.click(function() {
        var addthis_pub = 'usagov';
        var addthis_clickout = true;
        var addthis_url =  location.href;
        var addthis_title = document.title;
        return addthis_click(this);
      });
    });
  }
})(jQuery);

jQuery(document).ready(function() {
  jQuery('.share').each(function() {
    jQuery('.share').share();
  });
});

jQuery(document).ready(function () {
	jQuery('.nav li').hover(
		function () {
			//show submenu
			jQuery('ul', this).slideDown(100);
		},
		function () {
			//hide submenu
			jQuery('ul', this).slideUp(100);
		}
	);
});

jQuery(document).ready(function () {
    jQuery('#search_query').change(function() {
        update_vertical_navigation_links(jQuery(this).attr('value'));
    });
});

function update_vertical_navigation_links(new_text) {
    jQuery('.updatable').each(function(){
        var re = new RegExp("query=" + original_query, "");
        jQuery(this).attr('href', jQuery(this).attr('href').replace(re, "query=" + new_text));
    });
    original_query = new_text;
}

function toggle_more_or_less_options() {
  var selector = '#left_column .options-wrapper .triangle';
  jQuery('#left_column #show_options, #left_column #hide_options').toggle();
  jQuery(selector).toggleClass('show-options');
  jQuery(selector).toggleClass('hide-options');
  jQuery('#left_column .time-filters-and-facets-wrapper').slideToggle();
}

function toggle_facets(element) {
  jQuery(element).children('.more-facets, .less-facets').toggle();
  jQuery(element).children('.triangle').toggleClass('show-options');
  jQuery(element).children('.triangle').toggleClass('hide-options');
  jQuery(element).closest('ul.facet').children('.collapsible').slideToggle();
}

jQuery(document).ready(function() {
  jQuery('.options-wrapper').click(function() {
    toggle_more_or_less_options();
  });
  jQuery('.more-facets-wrapper').click(function() {
    toggle_facets(this);
  });
});