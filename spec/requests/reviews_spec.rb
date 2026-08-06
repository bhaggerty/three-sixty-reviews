require "rails_helper"

RSpec.describe "Reviews", type: :request do
  let(:manager) { build(:user) }
  let(:report) { build(:user, primary_manager_id: manager.id) }
  let(:assignment) { build(:review_assignment, reviewer_id: report.id, subject_id: manager.id, direction: "up") }

  before do
    UserRepository.new.upsert(manager)
    UserRepository.new.upsert(report)
    ReviewAssignmentRepository.new.create(assignment)
  end

  describe "GET /assignments/:id" do
    it "lets the assigned reviewer view the submission form" do
      sign_in(report)
      get assignment_path(assignment.id)
      expect(response).to have_http_status(:ok)
    end

    it "forbids someone unrelated to the assignment" do
      stranger = build(:user)
      sign_in(stranger)

      get assignment_path(assignment.id)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /assignments/:assignment_id/response" do
    it "submits and encrypts a response for the assigned reviewer" do
      sign_in(report)

      post assignment_response_path(assignment.id), params: {
        answers: { "q1_communication" => "5", "q6_strengths" => "Great mentor." }
      }

      expect(response).to redirect_to(assignments_path)
      saved = ReviewResponseRepository.new.for_assignment(assignment.id).first
      expect(saved).to be_finalized
    end

    it "forbids submission by someone who isn't the assigned reviewer" do
      sign_in(manager)

      post assignment_response_path(assignment.id), params: { answers: {} }

      expect(response).to have_http_status(:forbidden)
    end
  end
end
