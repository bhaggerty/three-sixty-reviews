require "rails_helper"

RSpec.describe ReviewAssignmentRepository do
  subject(:repository) { described_class.new }

  let(:cycle_id) { SecureRandom.uuid }
  let(:reviewer_id) { SecureRandom.uuid }
  let(:subject_id) { SecureRandom.uuid }

  describe "#create" do
    it "persists a new assignment" do
      assignment = build(:review_assignment, cycle_id: cycle_id, reviewer_id: reviewer_id, subject_id: subject_id)
      repository.create(assignment)

      found = repository.find(cycle_id, assignment.id)
      expect(found.reviewer_id).to eq(reviewer_id)
      expect(found.subject_id).to eq(subject_id)
    end

    it "is idempotent -- re-creating the same id returns the existing row instead of raising" do
      assignment = build(:review_assignment, cycle_id: cycle_id)
      repository.create(assignment)

      result = repository.create(assignment)

      expect(result.id).to eq(assignment.id)
    end
  end

  describe "#for_cycle" do
    it "lists all assignments in a cycle" do
      a1 = repository.create(build(:review_assignment, cycle_id: cycle_id))
      a2 = repository.create(build(:review_assignment, cycle_id: cycle_id))
      repository.create(build(:review_assignment, cycle_id: SecureRandom.uuid))

      expect(repository.for_cycle(cycle_id).map(&:id)).to match_array([ a1.id, a2.id ])
    end
  end

  describe "#to_review_by and #about" do
    it "separately surfaces 'reviews I need to write' and 'reviews about me' for the same person" do
      # This person is both a reviewer on one assignment and the subject of another --
      # the two GSIs (GSI2 by reviewer, GSI4 by subject) must not cross-contaminate.
      person_id = SecureRandom.uuid

      to_write = repository.create(build(:review_assignment, cycle_id: cycle_id, reviewer_id: person_id))
      about_me = repository.create(build(:review_assignment, cycle_id: cycle_id, subject_id: person_id))

      expect(repository.to_review_by(person_id).map(&:id)).to eq([ to_write.id ])
      expect(repository.about(person_id).map(&:id)).to eq([ about_me.id ])
    end

    it "filters by status when asked" do
      pending = repository.create(build(:review_assignment, cycle_id: cycle_id, reviewer_id: reviewer_id, status: "pending"))
      submitted = repository.create(build(:review_assignment, cycle_id: cycle_id, reviewer_id: reviewer_id, status: "submitted"))

      expect(repository.to_review_by(reviewer_id, status: "pending").map(&:id)).to eq([ pending.id ])
      expect(repository.to_review_by(reviewer_id, status: "submitted").map(&:id)).to eq([ submitted.id ])
    end
  end
end
