require "rails_helper"

RSpec.describe ShareRequestPolicy do
  let(:reviewer) { build(:user) }
  let(:subject_user) { build(:user) }
  let(:admin) { build(:user, :admin) }
  let(:stranger) { build(:user) }
  let(:assignment) { build(:review_assignment, reviewer_id: reviewer.id, subject_id: subject_user.id) }
  let(:share_request) { build(:share_request) }

  def policy_for(user)
    described_class.new(share_request, user: user, assignment: assignment)
  end

  describe "#create?" do
    it "allows either party in the review pairing" do
      expect(policy_for(reviewer).create?).to be true
      expect(policy_for(subject_user).create?).to be true
    end

    it "denies an unrelated stranger, even an admin acting outside the pairing" do
      expect(policy_for(stranger).create?).to be false
      expect(policy_for(admin).create?).to be false
    end
  end

  describe "#index? and #decide?" do
    it "allows only the admin to see or decide the approval queue" do
      expect(policy_for(admin).index?).to be true
      expect(policy_for(admin).decide?).to be true

      expect(policy_for(reviewer).index?).to be false
      expect(policy_for(reviewer).decide?).to be false
    end
  end
end
