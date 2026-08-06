module Reviews
  # The "verified-but-hidden identity" check: confirms a reviewer/subject
  # pairing is a real manager<->report relationship (per the current
  # primary-manager snapshot from the last org-chart resync), without that
  # verification ever surfacing the reviewer's identity to the subject.
  # Used both at assignment generation and again at submission time, since
  # a resync could have happened in between (v1 has no live sync/drift
  # tracking -- see plan doc -- so this is a point-in-time recheck against
  # whatever the last manual resync produced, not continuous validation).
  class EligibilityChecker
    def initialize(user_repository: UserRepository.new)
      @user_repository = user_repository
    end

    def eligible?(reviewer_id:, subject_id:, direction:)
      reviewer = user_repository.find(reviewer_id)
      subject = user_repository.find(subject_id)
      return false if reviewer.nil? || subject.nil?

      case direction
      when "up" then reviewer.primary_manager_id == subject.id
      when "down" then subject.primary_manager_id == reviewer.id
      else false
      end
    end

    private

    attr_reader :user_repository
  end
end
