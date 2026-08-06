FactoryBot.define do
  factory :user do
    id { SecureRandom.uuid }
    conductor_one_id { "c1-#{SecureRandom.hex(4)}" }
    slack_user_id { "U#{SecureRandom.hex(4).upcase}" }
    display_name { "Test User" }
    email { "test-#{SecureRandom.hex(3)}@conductorone.com" }

    trait :admin do
      slack_user_id { "ADMIN-TEST-SLACK-ID" }
    end
  end
end
