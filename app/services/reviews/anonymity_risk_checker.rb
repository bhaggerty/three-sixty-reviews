module Reviews
  # Detects the one un-fixable anonymity gap from the plan's threat model:
  # if a manager has exactly one direct report, upward feedback is
  # trivially attributable by elimination no matter how it's encrypted.
  # v1 response: warn the submitter before they submit, don't block.
  class AnonymityRiskChecker
    def initialize(user_repository: UserRepository.new)
      @user_repository = user_repository
    end

    def single_direct_report?(manager_id)
      user_repository.all.count { |u| u.primary_manager_id == manager_id } == 1
    end

    private

    attr_reader :user_repository
  end
end
