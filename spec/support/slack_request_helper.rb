ENV["SLACK_SIGNING_SECRET"] = "test-slack-signing-secret"

# Slack::SignatureVerifier's actual HMAC logic is covered directly and
# thoroughly in spec/services/slack/signature_verifier_spec.rb (valid sig,
# wrong secret, tampered body, replay window, missing headers). For these
# higher-level controller specs, stub verification to true so they can
# focus on controller/service behavior -- reproducing Rack::Test's exact
# request-body encoding byte-for-byte just to recompute a real HMAC over it
# tests Rack::Test's encoding, not this app's logic, and is fragile to boot.
module SlackRequestHelper
  def stub_valid_slack_signature!
    allow_any_instance_of(Slack::SignatureVerifier).to receive(:valid?).and_return(true)
  end

  def post_signed_slack(path, body_params)
    stub_valid_slack_signature!
    post path, params: body_params, headers: {
      "X-Slack-Request-Timestamp" => Time.now.to_i.to_s,
      "X-Slack-Signature" => "v0=stubbed"
    }
  end
end

RSpec.configure do |config|
  config.include SlackRequestHelper, type: :request
end
