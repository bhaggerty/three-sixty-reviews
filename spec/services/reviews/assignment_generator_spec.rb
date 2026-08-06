require "rails_helper"

RSpec.describe Reviews::AssignmentGenerator do
  subject(:generator) { described_class.new }

  let(:user_repository) { UserRepository.new }
  let(:assignment_repository) { ReviewAssignmentRepository.new }
  let(:cycle) { build(:review_cycle) }
  let(:manager) { build(:user) }
  let(:report) { build(:user, primary_manager_id: manager.id) }

  before do
    user_repository.upsert(manager)
    user_repository.upsert(report)
  end

  it "creates one up assignment and one down assignment per reporting relationship" do
    created = generator.generate_for_cycle(cycle)

    expect(created.map { |a| [ a.reviewer_id, a.subject_id, a.direction ] }).to match_array([
      [ report.id, manager.id, "up" ],
      [ manager.id, report.id, "down" ]
    ])
  end

  it "skips users with no resolvable primary manager" do
    orphan = build(:user, primary_manager_id: "nobody")
    user_repository.upsert(orphan)

    created = generator.generate_for_cycle(cycle)

    expect(created.map(&:reviewer_id)).not_to include(orphan.id)
  end

  it "is idempotent -- running it twice for the same cycle doesn't duplicate assignments" do
    generator.generate_for_cycle(cycle)
    generator.generate_for_cycle(cycle)

    expect(assignment_repository.for_cycle(cycle.id).size).to eq(2)
  end

  it "does not clobber an assignment that has already been submitted" do
    generator.generate_for_cycle(cycle)
    submitted = assignment_repository.to_review_by(report.id).first
    submitted.status = "submitted"
    assignment_repository.save(submitted)

    generator.generate_for_cycle(cycle)

    expect(assignment_repository.find(cycle.id, submitted.id).status).to eq("submitted")
  end
end
