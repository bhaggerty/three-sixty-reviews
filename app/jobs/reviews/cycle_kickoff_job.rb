module Reviews
  # Enqueued when an admin creates a review cycle. Generates assignments
  # from the current (last-resynced) org-chart snapshot and flips the
  # cycle to active.
  class CycleKickoffJob < ApplicationJob
    queue_as :default

    def perform(cycle_id)
      cycle_repository = ReviewCycleRepository.new
      cycle = cycle_repository.find(cycle_id)
      return if cycle.nil?

      Reviews::AssignmentGenerator.new.generate_for_cycle(cycle)

      cycle.status = "active"
      cycle_repository.upsert(cycle)
    end
  end
end
