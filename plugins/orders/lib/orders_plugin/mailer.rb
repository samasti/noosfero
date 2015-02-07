class OrdersPlugin::Mailer < Noosfero::Plugin::MailerBase

  include OrdersPlugin::TranslationHelper

  helper ApplicationHelper
  helper OrdersPlugin::OrdersDisplayHelper
  helper OrdersPlugin::DateHelper
  helper OrdersPlugin::TranslationHelper

  attr_accessor :environment
  attr_accessor :profile

  def message_to_consumer_for_order profile, order, subject, message = nil
    self.environment = profile.environment
    @profile = profile
    @order = order
    @consumer = order.consumer
    @message = message

    mail to: profile_recipients(order.consumer),
      from: environment.noreply_email,
      reply_to: profile_recipients(profile),
      subject: t('lib.mailer.profile_subject') % {profile: profile.name, subject: subject}
  end

  def message_to_consumer profile, consumer, subject, message
    self.environment = profile.environment
    @profile = profile
    @consumer = consumer
    @message = message
    @environment = profile.environment

    mail to: profile_recipients(consumer),
      from: environment.noreply_email,
      reply_to: profile_recipients(profile),
      subject: t('lib.mailer.profile_subject') % {profile: name, subject: subject}
  end

  def order_confirmation order
    profile = @profile = order.profile
    self.environment = profile.environment
    @order = order
    @consumer = order.consumer

    mail to: profile_recipients(order.consumer),
      from: environment.noreply_email,
      reply_to: profile_recipients(profile),
      subject: t('lib.mailer.order_was_confirmed') % {name: profile.name}
  end

  def order_cancellation order
    profile = @profile = order.profile
    self.environment = profile.environment
    @order = order
    @consumer = order.consumer
    @environment = profile.environment

    mail to: profile_recipients(order.consumer),
      from: environment.noreply_email,
      reply_to: profile_recipients(profile),
      subject: t('lib.mailer.order_was_cancelled') % {name: profile.name}
  end

  protected

  def profile_recipients profile
    if profile.person?
      profile.contact_email
    else
      profile.admins.map{ |p| p.contact_email }
    end
  end

end