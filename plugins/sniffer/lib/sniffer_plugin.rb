class SnifferPlugin < Noosfero::Plugin

  def self.plugin_name
    "Opportunity Sniffer"
  end

  def self.plugin_description
    _("Sniffs product suppliers and consumers near to your enterprise.")
  end

  def stylesheet?
    true
  end

  def js_files
    ['underscore-min.js', 'sniffer.js'].map{ |j| "javascripts/#{j}" }
  end

  def control_panel_buttons
    buttons = [{ :title => _("Consumer Interests"), :icon => 'consumer-interests', :url => {:controller => 'sniffer_plugin_myprofile', :action => 'edit'} }]
    buttons.push( { :title => _("Opportunities Sniffer"), :icon => 'sniff-opportunities', :url => {:controller => 'sniffer_plugin_myprofile', :action => 'search'} } ) if context.profile.enterprise?
    buttons
  end

  def self.extra_blocks
    { SnifferPlugin::InterestsBlock => {} }
  end

end
