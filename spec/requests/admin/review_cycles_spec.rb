require "rails_helper"

RSpec.describe "Admin::ReviewCycles", type: :request do
  let(:admin) { build(:user, :admin) }
  let(:non_admin) { build(:user) }

  describe "POST /admin/review_cycles" do
    it "creates a cycle and enqueues assignment generation for an admin" do
      sign_in(admin)

      expect {
        post admin_review_cycles_path, params: { name: "2026 H2" }
      }.to have_enqueued_job(Reviews::CycleKickoffJob)

      expect(response).to redirect_to(admin_review_cycles_path)
      expect(ReviewCycleRepository.new.all.map(&:name)).to include("2026 H2")
    end

    it "forbids a non-admin" do
      sign_in(non_admin)

      post admin_review_cycles_path, params: { name: "2026 H2" }

      expect(response).to have_http_status(:forbidden)
      expect(ReviewCycleRepository.new.all).to be_empty
    end
  end
end
