require "rails_helper"

RSpec.describe Kms::EnvelopeEncryptionService do
  subject(:service) { described_class.new }

  let(:context) { { "purpose" => "response_answers", "response_id" => "resp-1" } }

  describe "round trip" do
    it "decrypts back to the original plaintext" do
      envelope = service.encrypt("secret feedback content", context: context, key_alias: "alias/review-content")

      expect(service.decrypt(envelope, context: context)).to eq("secret feedback content")
    end

    it "produces a self-describing envelope with no plaintext leakage in stored fields" do
      envelope = service.encrypt("secret feedback content", context: context, key_alias: "alias/review-content")

      expect(envelope.values_at("ciphertext", "iv", "auth_tag", "encrypted_data_key")).to all(be_a(String))
      expect(envelope["kms_key_id"]).to eq("alias/review-content")
      expect(envelope.to_s).not_to include("secret feedback content")
    end
  end

  describe "encryption context binding" do
    it "raises when decrypting with a different context than was used to encrypt" do
      envelope = service.encrypt("secret", context: context, key_alias: "alias/review-content")
      wrong_context = context.merge("response_id" => "resp-2")

      expect {
        service.decrypt(envelope, context: wrong_context)
      }.to raise_error(Kms::EnvelopeEncryptionService::DecryptionFailed)
    end

    it "raises when decrypting with no context at all" do
      envelope = service.encrypt("secret", context: context, key_alias: "alias/review-content")

      expect {
        service.decrypt(envelope, context: {})
      }.to raise_error(Kms::EnvelopeEncryptionService::DecryptionFailed)
    end
  end

  it "uses a fresh random data key per encryption (envelopes for identical plaintext differ)" do
    envelope_a = service.encrypt("same content", context: context, key_alias: "alias/review-content")
    envelope_b = service.encrypt("same content", context: context, key_alias: "alias/review-content")

    expect(envelope_a["ciphertext"]).not_to eq(envelope_b["ciphertext"])
    expect(envelope_a["encrypted_data_key"]).not_to eq(envelope_b["encrypted_data_key"])
  end
end
