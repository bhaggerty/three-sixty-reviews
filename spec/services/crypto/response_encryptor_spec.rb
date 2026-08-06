require "rails_helper"

RSpec.describe Crypto::ResponseEncryptor do
  subject(:encryptor) { described_class.new }

  let(:response_id) { "resp-123" }
  let(:answers) { { "q1_rating" => 5, "q6_freeform" => "Great to work with." } }
  let(:attestation) { { "submitter_user_id" => "reviewer-abc", "verified_direct_report" => true } }

  describe "#build_envelopes and decrypt" do
    it "round-trips both envelopes" do
      envelopes = encryptor.build_envelopes(response_id: response_id, answers: answers, attestation: attestation)

      expect(encryptor.decrypt_answers(envelopes[:answers_envelope], response_id: response_id)).to eq(answers)
      expect(encryptor.decrypt_attestation(envelopes[:attestation_envelope], response_id: response_id)).to eq(attestation)
    end

    it "encrypts answers and attestation under different KMS key aliases" do
      envelopes = encryptor.build_envelopes(response_id: response_id, answers: answers, attestation: attestation)

      expect(envelopes[:answers_envelope]["kms_key_id"]).to eq("alias/review-content")
      expect(envelopes[:attestation_envelope]["kms_key_id"]).to eq("alias/review-attestation")
    end

    it "never puts submitter identity into the attestation envelope's encryption_context, since KMS logs that to CloudTrail in plaintext" do
      envelopes = encryptor.build_envelopes(response_id: response_id, answers: answers, attestation: attestation)

      context = envelopes[:attestation_envelope]["encryption_context"]
      expect(context.keys).to match_array(%w[purpose response_id])
      expect(context.values.join).not_to include("reviewer-abc")
    end

    it "cannot decrypt one response's attestation using another response's context" do
      envelopes = encryptor.build_envelopes(response_id: response_id, answers: answers, attestation: attestation)

      expect {
        encryptor.decrypt_attestation(envelopes[:attestation_envelope], response_id: "some-other-response")
      }.to raise_error(Kms::EnvelopeEncryptionService::DecryptionFailed)
    end
  end
end
