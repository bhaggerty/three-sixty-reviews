require "rails_helper"

RSpec.describe "ShareRequests", type: :request do
  let(:manager) { build(:user) }
  let(:report) { build(:user, primary_manager_id: manager.id) }
  let(:assignment) { build(:review_assignment, reviewer_id: report.id, subject_id: manager.id, direction: "up") }

  before do
    UserRepository.new.upsert(manager)
    UserRepository.new.upsert(report)
    ReviewAssignmentRepository.new.create(assignment)
    Reviews::SubmissionService.new.submit(
      assignment: assignment,
      submitter_id: report.id,
      answers: { "q1_communication" => 5 }
    )
  end

  describe "POST /assignments/:assignment_id/share_request" do
    it "lets either party in the pairing request a share, landing it in the admin queue rather than unlocking content" do
      sign_in(report)

      post assignment_share_request_path(assignment.id)

      expect(response).to redirect_to(assignment_path(assignment.id))
      response_id = ReviewResponseRepository.new.for_assignment(assignment.id).first.id
      expect(ShareRequestRepository.new.pending_queue.map(&:response_id)).to include(response_id)
      expect(GrantRepository.new.for_response(response_id)).to be_empty
    end

    it "forbids an unrelated stranger" do
      sign_in(build(:user))

      post assignment_share_request_path(assignment.id)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
