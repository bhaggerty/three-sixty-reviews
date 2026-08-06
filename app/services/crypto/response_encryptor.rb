module Crypto
  # Builds the two envelopes a ReviewResponse stores. The encryption_context
  # shape is centralized here specifically so nothing else in the codebase
  # can accidentally add reviewer/submitter identity into the attestation
  # envelope's context -- KMS logs encryption_context to CloudTrail in
  # plaintext, so doing that would defeat anonymity for anyone with
  # CloudTrail read access. See plan doc's threat-model notes.
  class ResponseEncryptor
    CONTENT_KEY_ALIAS = -> { ENV.fetch("KMS_CONTENT_KEY_ALIAS", "alias/review-content") }
    ATTESTATION_KEY_ALIAS = -> { ENV.fetch("KMS_ATTESTATION_KEY_ALIAS", "alias/review-attestation") }

    def initialize(encryption_service: Kms::EnvelopeEncryptionService.new)
      @encryption_service = encryption_service
    end

    def build_envelopes(response_id:, answers:, attestation:)
      {
        answers_envelope: encryption_service.encrypt(
          answers.to_json,
          context: answers_context(response_id),
          key_alias: CONTENT_KEY_ALIAS.call
        ),
        attestation_envelope: encryption_service.encrypt(
          attestation.to_json,
          context: attestation_context(response_id),
          key_alias: ATTESTATION_KEY_ALIAS.call
        )
      }
    end

    def decrypt_answers(envelope, response_id:)
      JSON.parse(encryption_service.decrypt(envelope, context: answers_context(response_id)))
    end

    def decrypt_attestation(envelope, response_id:)
      JSON.parse(encryption_service.decrypt(envelope, context: attestation_context(response_id)))
    end

    private

    attr_reader :encryption_service

    def answers_context(response_id)
      { "purpose" => "response_answers", "response_id" => response_id }
    end

    def attestation_context(response_id)
      { "purpose" => "response_attestation", "response_id" => response_id }
    end
  end
end
