FactoryBot.define do
  factory :review_response do
    id { SecureRandom.uuid }
    assignment_id { SecureRandom.uuid }
    question_set_version { "v1" }
    finalized { false }
    answers_envelope do
      { "ciphertext" => "stub", "iv" => "stub", "auth_tag" => "stub", "encrypted_data_key" => "stub", "kms_key_id" => "alias/review-content" }
    end
    attestation_envelope do
      { "ciphertext" => "stub", "iv" => "stub", "auth_tag" => "stub", "encrypted_data_key" => "stub", "kms_key_id" => "alias/review-attestation" }
    end
  end
end
