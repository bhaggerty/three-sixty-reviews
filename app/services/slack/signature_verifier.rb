module Slack
  # Verifies Slack's request signature (v0 HMAC-SHA256 scheme) so slash
  # command / interactivity payloads can be trusted without a Rails
  # session -- these endpoints are hit directly by Slack's servers.
  class SignatureVerifier
    REPLAY_WINDOW_SECONDS = 60 * 5

    def initialize(signing_secret: ENV.fetch("SLACK_SIGNING_SECRET", ""))
      @signing_secret = signing_secret
    end

    def valid?(timestamp:, signature:, body:)
      return false if timestamp.blank? || signature.blank?
      return false if (Time.now.to_i - timestamp.to_i).abs > REPLAY_WINDOW_SECONDS

      expected = "v0=#{OpenSSL::HMAC.hexdigest('SHA256', signing_secret, "v0:#{timestamp}:#{body}")}"
      ActiveSupport::SecurityUtils.secure_compare(expected, signature)
    end

    private

    attr_reader :signing_secret
  end
end
