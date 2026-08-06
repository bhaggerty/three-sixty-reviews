FactoryBot.define do
  factory :share_request do
    id { SecureRandom.uuid }
    response_id { SecureRandom.uuid }
    requested_by_id { SecureRandom.uuid }
    target_viewer_id { SecureRandom.uuid }
    status { "pending" }
  end
end
