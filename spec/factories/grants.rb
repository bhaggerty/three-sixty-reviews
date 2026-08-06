FactoryBot.define do
  factory :grant do
    id { SecureRandom.uuid }
    response_id { SecureRandom.uuid }
    scope { "CONTENT" }
    viewer_id { SecureRandom.uuid }
    granted_by_id { SecureRandom.uuid }
  end
end
