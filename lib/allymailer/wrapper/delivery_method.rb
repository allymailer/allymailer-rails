# frozen_string_literal: true

module AllyMailer
  module Wrapper
    # Action Mailer delivery method :allymailer, sends through email/send:
    #
    #   config.action_mailer.delivery_method = :allymailer
    #   config.action_mailer.allymailer_settings = { api_key: '...' } # optional, default: config.allymailer
    #
    # The API response ("job_id", "emails", "failed_emails") is in mail.delivery_method.response.
    class DeliveryMethod
      attr_accessor :settings
      attr_reader :response

      def initialize(settings = {})
        @settings = settings || {}
        @response = nil
      end

      def deliver!(mail)
        @response = client.api_client.call('/email/send.json', { 'message' => EmailPayload.from_mail(mail) })
      end

      private

      def client
        return ::AllyMailer::Wrapper.client if @settings[:api_key].nil?

        ::AllyMailer::Wrapper.build_client(@settings)
      end
    end
  end
end
