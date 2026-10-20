# frozen_string_literal: true

require 'rails/railtie'

module AllyMailer
  module Wrapper
    # config.allymailer settings, the :allymailer delivery method of Action Mailer and the webhook route.
    class Railtie < ::Rails::Railtie
      config.allymailer = ::AllyMailer::Wrapper.default_configuration

      initializer 'allymailer.configure' do |app|
        options = app.config.allymailer
        if options.api_key.nil? || options.api_key.to_s.empty?
          credentials = begin
            app.credentials.allymailer
          rescue StandardError
            nil
          end
          options.api_key = credentials[:api_key] if credentials.respond_to?(:[])
        end
        ::AllyMailer::Wrapper.configuration = options
      end

      initializer 'allymailer.action_mailer' do
        ActiveSupport.on_load(:action_mailer) do
          add_delivery_method :allymailer, ::AllyMailer::Wrapper::DeliveryMethod
        end
      end

      initializer 'allymailer.webhook_route' do |app|
        options = app.config.allymailer
        if options.webhook_enabled != false
          app.routes.prepend do
            match options.webhook_path, to: ::AllyMailer::Wrapper::WebhookEndpoint.new, via: %i[get head post],
                                        as: 'allymailer_webhook'
          end
        end
      end
    end
  end
end
