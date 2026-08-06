require "rails_helper"

RSpec.describe Sharing::GrantService do
  subject(:service) { described_class.new }

  let(:admin) { build(:user, :admin) }
  let(:non_admin) { build(:user) }
  let(:share_request) { ShareRequestRepository.new.create(build(:share_request)) }

  describe "#approve" do
    it "creates a CONTENT grant for the target viewer and marks the request approved" do
      grant = service.approve(share_request: share_request, admin: admin)

      expect(grant.scope).to eq("CONTENT")
      expect(grant.viewer_id).to eq(share_request.target_viewer_id)
      expect(GrantRepository.new.active?(share_request.response_id, "CONTENT", share_request.target_viewer_id)).to be true

      decided = ShareRequestRepository.new.find(share_request.response_id, share_request.id)
      expect(decided.status).to eq("approved")
    end

    it "raises NotAdmin for a non-admin caller, and does not create a grant" do
      expect {
        service.approve(share_request: share_request, admin: non_admin)
      }.to raise_error(Sharing::GrantService::NotAdmin)

      expect(GrantRepository.new.for_response(share_request.response_id)).to be_empty
    end

    it "raises AlreadyDecided if the request was already approved" do
      service.approve(share_request: share_request, admin: admin)

      expect {
        service.approve(share_request: share_request, admin: admin)
      }.to raise_error(Sharing::GrantService::AlreadyDecided)
    end

    it "removes the request from the admin's pending queue" do
      request_id = share_request.id # force the `let` to create it before we query the queue
      expect(ShareRequestRepository.new.pending_queue.map(&:id)).to include(request_id)

      service.approve(share_request: share_request, admin: admin)

      expect(ShareRequestRepository.new.pending_queue.map(&:id)).not_to include(request_id)
    end
  end

  describe "#deny" do
    it "marks the request denied without creating any grant" do
      service.deny(share_request: share_request, admin: admin)

      expect(GrantRepository.new.for_response(share_request.response_id)).to be_empty
      expect(ShareRequestRepository.new.find(share_request.response_id, share_request.id).status).to eq("denied")
    end
  end
end
