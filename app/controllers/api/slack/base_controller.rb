# Slack POSTs directly to these endpoints (no Rails session, no CSRF token,
# no current_user from a cookie) -- deliberately does NOT inherit
# ApplicationController, since that would pull in :require_login and a
# session-based auth context that doesn't apply here. Every request is
# instead authenticated by Slack's own request signature.
module Api
  module Slack
    class BaseController < ActionController::Base
      skip_before_action :verify_authenticity_token, raise: false
      before_action :verify_slack_signature!

      private

      def verify_slack_signature!
        body = request.body.read
        request.body.rewind

        verifier = ::Slack::SignatureVerifier.new
        unless verifier.valid?(
          timestamp: request.headers["X-Slack-Request-Timestamp"],
          signature: request.headers["X-Slack-Signature"],
          body: body
        )
          head :unauthorized
        end
      end

      def current_app_user
        @current_app_user ||= begin
          slack_user_id = params[:user_id] || interaction_payload.dig("user", "id")
          UserRepository.new.find_by_slack_id(slack_user_id)
        end
      end

      # Interactivity payloads (block actions, view_submission) arrive as a
      # form field named "payload" containing a JSON string.
      def interaction_payload
        @interaction_payload ||= params[:payload].present? ? JSON.parse(params[:payload]) : {}
      end
    end
  end
end
