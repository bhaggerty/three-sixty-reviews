module Reviews
  # Builds ReviewAssignment rows for a cycle from the current User snapshot
  # (populated by the last manual org-chart resync -- see
  # OrgChart::ResyncService). v1 uses each person's *primary* manager only
  # (User#primary_manager_id), producing one "up" assignment (report reviews
  # manager) and one "down" assignment (manager reviews report) per
  # reporting relationship.
  class AssignmentGenerator
    def initialize(user_repository: UserRepository.new, assignment_repository: ReviewAssignmentRepository.new)
      @user_repository = user_repository
      @assignment_repository = assignment_repository
    end

    # Deterministic assignment ids (hash of cycle/reviewer/subject/direction)
    # make this idempotent: re-running generate_for_cycle for a cycle that
    # already has assignments is a no-op for existing pairs (the repository's
    # ensure_new conditional put just returns the existing row) rather than
    # creating duplicates or clobbering in-progress/submitted assignments.
    def generate_for_cycle(cycle)
      users = user_repository.all
      users_by_id = users.index_by(&:id)

      users.filter_map do |user|
        manager = users_by_id[user.primary_manager_id]
        next if manager.nil?

        [
          create_assignment(cycle: cycle, reviewer: user, subject: manager, direction: "up"),
          create_assignment(cycle: cycle, reviewer: manager, subject: user, direction: "down")
        ]
      end.flatten
    end

    private

    attr_reader :user_repository, :assignment_repository

    def create_assignment(cycle:, reviewer:, subject:, direction:)
      assignment = ReviewAssignment.new(
        id: deterministic_id(cycle.id, reviewer.id, subject.id, direction),
        cycle_id: cycle.id,
        reviewer_id: reviewer.id,
        subject_id: subject.id,
        direction: direction,
        status: "pending",
        snapshot_taken_at: Time.current
      )
      assignment_repository.create(assignment)
    end

    def deterministic_id(cycle_id, reviewer_id, subject_id, direction)
      Digest::SHA256.hexdigest("#{cycle_id}:#{reviewer_id}:#{subject_id}:#{direction}")
    end
  end
end
