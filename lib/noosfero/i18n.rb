require 'fast_gettext'

class Object
  include FastGettext::Translation
  alias :gettext :_
  alias :ngettext :n_
  alias :c_ :_
  alias :cN_ :N_
end


# Adds custom locales for a whole environment
custom_locale_dir = Rails.root.join('config', 'custom_locales', Rails.env)
repos = []
if File.exists?(custom_locale_dir)
  repos << FastGettext::TranslationRepository.build('environment', :type => 'po', :path => custom_locale_dir)
end

Dir.glob('{baseplugins,config/plugins}/*/locale') do |plugin_locale_dir|
  plugin = File.basename(File.dirname(plugin_locale_dir))
  repos << FastGettext::TranslationRepository.build(plugin, :type => 'mo', :path => plugin_locale_dir)
end

# translations in place?
locale_dir = Rails.root.join('locale')
if File.exists?(locale_dir)
  repos << FastGettext::TranslationRepository.build('noosfero', :type => 'mo', :path => locale_dir)
  repos << FastGettext::TranslationRepository.build('iso_3166', :type => 'mo', :path => locale_dir)
end

FastGettext.add_text_domain 'noosfero', :type => :chain, :chain => repos
FastGettext.default_text_domain = 'noosfero'

# Adds custom locales for specific domains; Domains are identified by the
# sequence before the first dot, while tenants are identified by schema name
hosted_environments = Noosfero::MultiTenancy.mapping.values
hosted_environments += Domain.all.map { |domain| domain.name[/(.*?)\./,1] } if Domain.table_exists?

hosted_environments.uniq.each do |env|
  custom_locale_dir = Rails.root.join('config', 'custom_locales', env)
  if File.exists?(custom_locale_dir)
    FastGettext.add_text_domain(env, :type => :chain, :chain => [FastGettext::TranslationRepository.build('environment', :type => 'po', :path => custom_locale_dir)] + repos)
  end
end

# Setup fallbacks

class FastGettext::TranslationRepository::Base
  attr_accessor :files
end
class FastGettext::MoFile
  attr_accessor :data
end
module FastGettext
  @@fallbacks = {
    'en_US' => 'en',
    'pt_BR' => 'pt',
    'fr_FR' => 'fr',
    'hy_AM' => 'hy',
    'de_DE' => 'de',
    'ru_RU' => 'ru',
    'es_ES' => 'es',
    'it_IT' => 'it',
  }

  def self.fallbacks
    @@fallbacks
  end
end

FastGettext.translation_repositories.each do |domain, repository|
  repository.chain.each do |chain|
    new_files = {}

    files = chain.files
    files.each do |locale, file|
      FastGettext.fallbacks.each do |dest, source|
        next if locale != source

        mo_file = files[dest]
        unless mo_file
          mo_file ||= FastGettext::MoFile.empty
          new_files[dest] = mo_file
        end

        mo_file.data = file.data.merge mo_file.data
      end
    end

    files.merge! new_files
  end
end

