require_dependency 'profile'

ActiveSupport.run_load_hooks :solr_profile

class Profile

  SEARCH_FILTERS[:order] = []

  # use for internationalizable human type names in search facets
  # reimplement on subclasses
  def self.type_name
    c_('Profile')
  end

  after_save_reindex [:articles], with: :delayed_job

  class_attribute :solr_extra_index_methods
  self.solr_extra_index_methods = []

  def solr_extra_data_for_index
    self.class.solr_extra_index_methods.map { |meth| meth.to_proc.call(self) }.flatten
  end

  def self.solr_extra_data_for_index(sym = nil, &block)
    self.solr_extra_index_methods ||= []
    self.solr_extra_index_methods.push(sym) if sym
    self.solr_extra_index_methods.push(block) if block_given?
  end

  def add_category_with_solr_save(c, reload=false)
    add_category_without_solr_save(c, reload)
    if !new_record?
      self.solr_save
    end
  end
  alias_method_chain :add_category, :solr_save

  protected

  def self.solr_f_categories_label_proc environment
    ids = environment.solr_plugin_top_level_category_as_facet_ids
    map, r = {}, Category.where(id: ids)
    ids.map{ |id| map[id.to_s] = r.detect{|c| c.id == id}.name }
    map
  end

  def self.solr_f_categories_proc facet, id_count_arr
    ids = id_count_arr.map{ |id, count| id }
    cats, r = [], Category.where(id: ids)
    ids.each{ |id| cats << r.detect{ |c| c.id == id.to_i} }
    cats.reject! do |c|
      !(c.top_ancestor.id == facet[:label_id].to_i || facet[:label_id] == 0) rescue nil
    end

    count_hash = Hash[id_count_arr]
    cats.map do |cat|
      [cat.id.to_s, cat.name, count_hash[cat.id.to_s]]
    end
  end

  def solr_f_categories
    category_ids - [region_id]
  end

  def solr_f_region
    self.region_id.to_s
  end

  def self.solr_f_region_title region
    if region
      if region.kind_of?(City)
        city_with_state(region)
      else
        region.name
      end
    else
      nil
    end
  end

  def self.solr_f_region_label_proc environment
    case environment.solr_plugin_region_facet_type
      when :city
        c_('City')
      when :state
        c_('State')
      when :region
        c_('Region')
      else
        c_('City')
    end
  end

  def self.solr_f_region_proc facet, id_count_arr
    ids = id_count_arr.map{ |id, count| id }
    regs, r = [], Region.where(id: ids).includes(:parent)
    ids.each do |id|
      c = r.detect{ |c| c.id == id.to_i}
      regs << c if c
    end

    count_hash = Hash[id_count_arr]
    extend SearchHelper
    regs.map do |c|
      [c.id.to_s, solr_f_region_title(c), count_hash[c.id.to_s]]
    end
  end

  def self.solr_f_enabled_proc facet, id_count_arr
    id_count_arr.map do |enabled, count|
      enabled = enabled == "true" ? true : false
      text = if enabled then s_('facets|Enabled') else s_('facets|Not enabled') end
      [enabled, text, count]
    end
  end

  def solr_f_enabled
    self.enabled
  end

  def solr_is_public
    self.public?
  end

  def solr_category_filter
    categories_including_virtual_ids
  end

  def solr_name_sortable
    name
  end

  def solr_f_profile_type
    self.class.name
  end

  def self.solr_f_profile_type_proc facet, id_count_arr
    id_count_arr.map do |type, count|
      [type, type.constantize.type_name, count]
    end
  end

  extend SolrPlugin::ActsAsSearchable
  extend SolrPlugin::ActsAsFaceted

  acts_as_faceted fields: {
      solr_f_enabled: {
        label: _('Situation'), type_if: -> (klass) { klass.kind_of? Enterprise },
        proc: method(:solr_f_enabled_proc).to_proc
      },
      solr_f_region: {
        label: c_('State'), type_if: -> (klass) { not klass.kind_of? Community },
        proc: method(:solr_f_region_proc).to_proc,
      },
      solr_f_categories: {
        multi: true, proc: method(:solr_f_categories_proc).to_proc, label: -> (env) { solr_f_categories_label_proc(env) },
        label_abbrev: -> (env) { solr_f_categories_label_abbrev_proc env },
      },
      #solr_f_profile_type: {
      #  label: c_('Type'), type_if: -> (klass) { klass.kind_of? Enterprise },
      #  proc: method(:solr_f_profile_type_proc).to_proc,
      #},
    }, category_query: -> (c) { "solr_category_filter:#{c.id}" },
    order: [:solr_f_region, :solr_f_categories, :solr_f_enabled, :solr_f_profile_type]

  acts_as_searchable fields: [
      :solr_extra_data_for_index,
      # searched fields
      {name: {type: :text, boost: 2.0}}, {nickname: :text}, {display_name: :text},
      {identifier: :text}, {contact_email: :text},
      # filtered fields
      {solr_is_public: :boolean}, {environment_id: :integer},
      {solr_category_filter: :integer},
      # scopes
      {no_templates: :boolean},
      # ordered/query-boosted fields
      {solr_name_sortable: :string}, {user_id: :integer},
      :enabled, :active, :validated, :public_profile, :visible, :is_template, :secret, :type,
      {lat: :float}, {lng: :float},
      :updated_at, :created_at,
    ],
    include: [
      {region: {fields: [:name, :path, :slug, :lat, :lng]}},
      {categories: {fields: [:name, :path, :slug, :lat, :lng, :acronym, :abbreviation]}},
    ], facets: self.solr_facets_options,
    boost: -> (p) { 10 if p.enabled }

  def no_templates
    !self.is_template
  end

end
