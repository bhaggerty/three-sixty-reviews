FactoryBot.define do
  factory :review_cycle do
    id { SecureRandom.uuid }
    name { "2026 H2" }
    status { "active" }
    question_set_version { "v1" }
  end
end
