require "rails_helper"

RSpec.describe ReviewAssignmentPolicy do
  let(:reviewer) { build(:user) }
  let(:subject_user) { build(:user) }
  let(:admin) { build(:user, :admin) }
  let(:stranger) { build(:user) }
  let(:assignment) { build(:review_assignment, reviewer_id: reviewer.id, subject_id: subject_user.id) }

  describe "#show?" do
    it "allows the reviewer, the subject, and the admin" do
      expect(described_class.new(assignment, user: reviewer).show?).to be true
      expect(described_class.new(assignment, user: subject_user).show?).to be true
      expect(described_class.new(assignment, user: admin).show?).to be true
    end

    it "denies an unrelated user" do
      expect(described_class.new(assignment, user: stranger).show?).to be false
    end
  end

  describe "#submit?" do
    it "allows only the assigned reviewer" do
      expect(described_class.new(assignment, user: reviewer).submit?).to be true
      expect(described_class.new(assignment, user: subject_user).submit?).to be false
    end
  end
end
