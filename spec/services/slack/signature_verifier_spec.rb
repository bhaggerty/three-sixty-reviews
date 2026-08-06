require "rails_helper"

RSpec.describe Slack::SignatureVerifier do
  subject(:verifier) { described_class.new(signing_secret: "test-signing-secret") }

  def sign(timestamp, body)
    "v0=" + OpenSSL::HMAC.hexdigest("SHA256", "test-signing-secret", "v0:#{timestamp}:#{body}")
  end

  it "accepts a correctly signed, fresh request" do
    timestamp = Time.now.to_i.to_s
    body = "command=/review"

    expect(verifier.valid?(timestamp: timestamp, signature: sign(timestamp, body), body: body)).to be true
  end

  it "rejects a request signed with the wrong secret" do
    timestamp = Time.now.to_i.to_s
    body = "command=/review"
    wrong_signature = "v0=" + OpenSSL::HMAC.hexdigest("SHA256", "someone-elses-secret", "v0:#{timestamp}:#{body}")

    expect(verifier.valid?(timestamp: timestamp, signature: wrong_signature, body: body)).to be false
  end

  it "rejects a tampered body even with a valid-looking signature for the original body" do
    timestamp = Time.now.to_i.to_s
    original_body = "command=/review"
    tampered_body = "command=/review&user_id=someone-else"

    expect(verifier.valid?(timestamp: timestamp, signature: sign(timestamp, original_body), body: tampered_body)).to be false
  end

  it "rejects a replayed request older than the 5 minute window" do
    old_timestamp = (Time.now.to_i - 600).to_s
    body = "command=/review"

    expect(verifier.valid?(timestamp: old_timestamp, signature: sign(old_timestamp, body), body: body)).to be false
  end

  it "rejects when timestamp or signature is missing" do
    expect(verifier.valid?(timestamp: nil, signature: "v0=x", body: "b")).to be false
    expect(verifier.valid?(timestamp: Time.now.to_i.to_s, signature: nil, body: "b")).to be false
  end
end
