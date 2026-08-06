require "rails_helper"

RSpec.describe Reviews::CycleKickoffJob do
  it "generates assignments from the current org-chart snapshot and activates the cycle" do
    manager = UserRepository.new.upsert(build(:user))
    report = UserRepository.new.upsert(build(:user, primary_manager_id: manager.id))
    cycle = ReviewCycleRepository.new.upsert(build(:review_cycle, status: "draft"))

    described_class.perform_now(cycle.id)

    assignments = ReviewAssignmentRepository.new.for_cycle(cycle.id)
    expect(assignments.map { |a| [ a.reviewer_id, a.subject_id ] }).to include([ report.id, manager.id ])
    expect(ReviewCycleRepository.new.find(cycle.id).status).to eq("active")
  end

  it "is a no-op if the cycle doesn't exist (e.g. raced with a delete)" do
    expect { described_class.perform_now("does-not-exist") }.not_to raise_error
  end
end
