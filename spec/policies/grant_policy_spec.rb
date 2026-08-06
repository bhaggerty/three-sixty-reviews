require "rails_helper"

RSpec.describe GrantPolicy do
  let(:viewer) { build(:user) }
  let(:admin) { build(:user, :admin) }
  let(:stranger) { build(:user) }
  let(:grant) { build(:grant, viewer_id: viewer.id) }

  describe "#show?" do
    it "allows the viewer the grant was made for, and the admin" do
      expect(described_class.new(grant, user: viewer).show?).to be true
      expect(described_class.new(grant, user: admin).show?).to be true
    end

    it "denies anyone else" do
      expect(described_class.new(grant, user: stranger).show?).to be false
    end
  end

  describe "#manage?" do
    it "allows only the admin" do
      expect(described_class.new(grant, user: admin).manage?).to be true
      expect(described_class.new(grant, user: viewer).manage?).to be false
    end
  end
end
