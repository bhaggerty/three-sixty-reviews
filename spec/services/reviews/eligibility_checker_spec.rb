require "rails_helper"

RSpec.describe Reviews::EligibilityChecker do
  subject(:checker) { described_class.new }

  let(:user_repository) { UserRepository.new }
  let(:manager) { build(:user) }
  let(:report) { build(:user, primary_manager_id: manager.id) }

  before do
    user_repository.upsert(manager)
    user_repository.upsert(report)
  end

  it "confirms an upward pairing when the reviewer's primary manager matches the subject" do
    expect(checker.eligible?(reviewer_id: report.id, subject_id: manager.id, direction: "up")).to be true
  end

  it "confirms a downward pairing when the subject's primary manager matches the reviewer" do
    expect(checker.eligible?(reviewer_id: manager.id, subject_id: report.id, direction: "down")).to be true
  end

  it "rejects an upward pairing against the wrong manager" do
    other_manager = build(:user)
    user_repository.upsert(other_manager)

    expect(checker.eligible?(reviewer_id: report.id, subject_id: other_manager.id, direction: "up")).to be false
  end

  it "rejects when either user doesn't exist" do
    expect(checker.eligible?(reviewer_id: "ghost", subject_id: manager.id, direction: "up")).to be false
  end
end
