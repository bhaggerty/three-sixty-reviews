require "rails_helper"

RSpec.describe ShareRequestRepository do
  subject(:repository) { described_class.new }

  describe "#pending_queue" do
    it "surfaces pending share requests" do
      pending = repository.create(build(:share_request, status: "pending"))

      expect(repository.pending_queue.map(&:id)).to include(pending.id)
    end

    it "drops a request from the queue once it's decided, without needing to filter by status" do
      request = repository.create(build(:share_request, status: "pending"))
      expect(repository.pending_queue.map(&:id)).to include(request.id)

      request.status = "approved"
      request.decided_at = Time.current
      request.decided_by_id = SecureRandom.uuid
      repository.save(request)

      expect(repository.pending_queue.map(&:id)).not_to include(request.id)
      # but it's still retrievable directly -- only the sparse index entry is gone
      expect(repository.find(request.response_id, request.id).status).to eq("approved")
    end
  end
end
