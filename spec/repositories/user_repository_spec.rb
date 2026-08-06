require "rails_helper"

RSpec.describe UserRepository do
  subject(:repository) { described_class.new }

  describe "#upsert and #find" do
    it "round-trips a user by id" do
      user = build(:user)
      repository.upsert(user)

      found = repository.find(user.id)

      expect(found.id).to eq(user.id)
      expect(found.slack_user_id).to eq(user.slack_user_id)
      expect(found.display_name).to eq(user.display_name)
    end

    it "returns nil for an unknown id" do
      expect(repository.find("does-not-exist")).to be_nil
    end
  end

  describe "#find_by_slack_id" do
    it "resolves a user via the Slack identity GSI" do
      user = build(:user, slack_user_id: "U123ABC")
      repository.upsert(user)

      found = repository.find_by_slack_id("U123ABC")

      expect(found.id).to eq(user.id)
    end

    it "returns nil when no user has that Slack id" do
      expect(repository.find_by_slack_id("UNKNOWN")).to be_nil
    end
  end

  describe "#all" do
    it "returns every persisted user" do
      users = Array.new(3) { build(:user) }
      users.each { |u| repository.upsert(u) }

      expect(repository.all.map(&:id)).to match_array(users.map(&:id))
    end
  end
end
