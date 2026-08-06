require "rails_helper"

# Same nested-namespace gotcha coverage as the ShareRequests controller spec.
RSpec.describe "Admin::Reviews::Grants", type: :request do
  let(:admin) { build(:user, :admin) }
  let(:non_admin) { build(:user) }
  let(:grant) { GrantRepository.new.create(build(:grant)) }

  describe "GET /admin/reviews/grants" do
    it "does not 500 on the nested namespace, and lists grants for an admin" do
      sign_in(admin)
      grant_id = grant.id

      get admin_reviews_grants_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(grant_id)
    end

    it "forbids (not 500s) a non-admin" do
      sign_in(non_admin)

      get admin_reviews_grants_path

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /admin/reviews/grants/:id/revoke" do
    it "revokes for an admin without 500ing" do
      sign_in(admin)

      post revoke_admin_reviews_grant_path(grant.id)

      expect(response).to redirect_to(admin_reviews_grants_path)
      expect(GrantRepository.new.for_response(grant.response_id).first.active?).to be false
    end

    it "forbids (not 500s) a non-admin, and does not revoke" do
      sign_in(non_admin)

      post revoke_admin_reviews_grant_path(grant.id)

      expect(response).to have_http_status(:forbidden)
      expect(GrantRepository.new.for_response(grant.response_id).first.active?).to be true
    end
  end
end
