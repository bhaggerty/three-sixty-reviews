require "rails_helper"

RSpec.describe Reviews::SubmissionService do
  subject(:service) { described_class.new }

  let(:user_repository) { UserRepository.new }
  let(:assignment_repository) { ReviewAssignmentRepository.new }
  let(:response_repository) { ReviewResponseRepository.new }

  let(:manager) { build(:user) }
  let(:report) { build(:user, primary_manager_id: manager.id) }
  let(:assignment) { build(:review_assignment, reviewer_id: report.id, subject_id: manager.id, direction: "up") }
  let(:answers) { { "q1_communication" => 4, "q6_strengths" => "Very clear." } }

  before do
    user_repository.upsert(manager)
    user_repository.upsert(report)
    assignment_repository.create(assignment)
  end

  it "encrypts and stores a finalized response, and marks the assignment submitted" do
    response = service.submit(assignment: assignment, submitter_id: report.id, answers: answers)

    expect(response).to be_finalized
    expect(response.answers_envelope).to be_a(Hash)
    expect(response.attestation_envelope).to be_a(Hash)

    saved_assignment = assignment_repository.find(assignment.cycle_id, assignment.id)
    expect(saved_assignment.status).to eq("submitted")
  end

  it "raises NotEligible if the reviewer/subject pairing doesn't match the org-chart snapshot" do
    stranger = build(:user)
    user_repository.upsert(stranger)
    bogus_assignment = build(:review_assignment, reviewer_id: report.id, subject_id: stranger.id, direction: "up")
    assignment_repository.create(bogus_assignment)

    expect {
      service.submit(assignment: bogus_assignment, submitter_id: report.id, answers: answers)
    }.to raise_error(Reviews::SubmissionService::NotEligible)
  end

  it "raises NotAssignedReviewer if the submitter isn't the assignment's reviewer" do
    expect {
      service.submit(assignment: assignment, submitter_id: manager.id, answers: answers)
    }.to raise_error(Reviews::SubmissionService::NotAssignedReviewer)
  end

  it "raises AlreadyFinalized on a second submission attempt" do
    service.submit(assignment: assignment, submitter_id: report.id, answers: answers)

    expect {
      service.submit(assignment: assignment, submitter_id: report.id, answers: answers)
    }.to raise_error(Reviews::SubmissionService::AlreadyFinalized)
  end

  it "records verified_direct_report: true in the attestation when eligibility holds" do
    response = service.submit(assignment: assignment, submitter_id: report.id, answers: answers)

    encryptor = Crypto::ResponseEncryptor.new
    attestation = encryptor.decrypt_attestation(response.attestation_envelope, response_id: response.id)

    expect(attestation["submitter_user_id"]).to eq(report.id)
    expect(attestation["verified_direct_report"]).to be true
  end
end
