FactoryBot.define do
  factory :review_assignment do
    id { SecureRandom.uuid }
    cycle_id { SecureRandom.uuid }
    reviewer_id { SecureRandom.uuid }
    subject_id { SecureRandom.uuid }
    direction { "up" }
    status { "pending" }
  end
end
