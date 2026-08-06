require "rails_helper"

# This controller is nested two levels deep (Admin::Reviews::) -- the known
# action_policy gotcha (see memory: feedback_action_policy_nested_namespace)
# is that bare `authorize!` fails to infer the policy class at this depth
# and 500s. These specs exist specifically to catch a regression if the
# explicit `with: ShareRequestPolicy` ever gets dropped from this
# controller.
RSpec.describe "Admin::Reviews::ShareRequests", type: :request do
  let(:admin) { build(:user, :admin) }
  let(:non_admin) { build(:user) }
  let(:share_request) { ShareRequestRepository.new.create(build(:share_request)) }

  describe "GET /admin/reviews/share_requests" do
    it "does not 500 on the nested namespace, and lists the pending queue for an admin" do
      sign_in(admin)
      request_id = share_request.id

      get admin_reviews_share_requests_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(request_id)
    end

    it "forbids (not 500s) a non-admin" do
      sign_in(non_admin)

      get admin_reviews_share_requests_path

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /admin/reviews/share_requests/:id/approve" do
    it "does not 500 on the nested namespace, and approves for an admin" do
      sign_in(admin)

      post approve_admin_reviews_share_request_path(share_request.id)

      expect(response).to redirect_to(admin_reviews_share_requests_path)
      expect(ShareRequestRepository.new.find(share_request.response_id, share_request.id).status).to eq("approved")
    end

    it "forbids (not 500s) a non-admin, and does not approve" do
      sign_in(non_admin)

      post approve_admin_reviews_share_request_path(share_request.id)

      expect(response).to have_http_status(:forbidden)
      expect(ShareRequestRepository.new.find(share_request.response_id, share_request.id).status).to eq("pending")
    end
  end

  describe "POST /admin/reviews/share_requests/:id/deny" do
    it "denies for an admin without 500ing" do
      sign_in(admin)

      post deny_admin_reviews_share_request_path(share_request.id)

      expect(response).to redirect_to(admin_reviews_share_requests_path)
      expect(ShareRequestRepository.new.find(share_request.response_id, share_request.id).status).to eq("denied")
    end
  end
end
