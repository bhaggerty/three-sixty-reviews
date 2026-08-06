require "rails_helper"

RSpec.describe ReviewResponsePolicy do
  let(:reviewer) { build(:user) }
  let(:subject_user) { build(:user) }
  let(:admin) { build(:user, :admin) }
  let(:stranger) { build(:user) }
  let(:assignment) { build(:review_assignment, reviewer_id: reviewer.id, subject_id: subject_user.id) }
  let(:response) { build(:review_response, assignment_id: assignment.id) }

  def policy_for(user)
    described_class.new(response, user: user, assignment: assignment)
  end

  describe "#show_content?" do
    it "allows the submitter to see their own written content" do
      expect(policy_for(reviewer).show_content?).to be true
    end

    it "allows the admin" do
      expect(policy_for(admin).show_content?).to be true
    end

    it "denies the recipient with no grant" do
      expect(policy_for(subject_user).show_content?).to be false
    end

    it "allows the recipient once an active CONTENT grant exists" do
      GrantRepository.new.create(build(:grant, response_id: response.id, scope: "CONTENT", viewer_id: subject_user.id))

      expect(policy_for(subject_user).show_content?).to be true
    end

    it "denies a revoked grant" do
      grant = GrantRepository.new.create(build(:grant, response_id: response.id, scope: "CONTENT", viewer_id: subject_user.id))
      grant.revoked_at = Time.current
      GrantRepository.new.save(grant)

      expect(policy_for(subject_user).show_content?).to be false
    end

    it "denies an unrelated stranger" do
      expect(policy_for(stranger).show_content?).to be false
    end

    it "does not let an ATTESTATION-scope grant substitute for a CONTENT grant" do
      GrantRepository.new.create(build(:grant, response_id: response.id, scope: "ATTESTATION", viewer_id: subject_user.id))

      expect(policy_for(subject_user).show_content?).to be false
    end
  end

  describe "#show_attestation?" do
    it "allows only the admin, never the submitter, the recipient, or a grant holder" do
      GrantRepository.new.create(build(:grant, response_id: response.id, scope: "ATTESTATION", viewer_id: subject_user.id))

      expect(policy_for(admin).show_attestation?).to be true
      expect(policy_for(reviewer).show_attestation?).to be false
      expect(policy_for(subject_user).show_attestation?).to be false
      expect(policy_for(stranger).show_attestation?).to be false
    end
  end
end
