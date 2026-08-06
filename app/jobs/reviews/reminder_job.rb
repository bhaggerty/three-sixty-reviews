module Reviews
  # DMs each reviewer with a pending assignment in every active cycle.
  # Not scheduled automatically in v1 (no cron primitive assumed) -- an
  # admin action or an external scheduler triggers this by enqueuing it.
  class ReminderJob < ApplicationJob
    queue_as :default

    def perform
      active_cycles = ReviewCycleRepository.new.all.select(&:active?)

      active_cycles.each do |cycle|
        ReviewAssignmentRepository.new.for_cycle(cycle.id).select(&:pending?).each do |assignment|
          remind(assignment)
        end
      end
    end

    private

    def remind(assignment)
      reviewer = UserRepository.new.find(assignment.reviewer_id)
      return if reviewer&.slack_user_id.blank?

      Slack::WebApiClient.new.chat_post_message(
        channel: reviewer.slack_user_id,
        text: "You have a pending #{assignment.upward? ? 'manager' : 'report'} review to fill out. " \
              "Run /review in Slack, or visit the web app."
      )
    end
  end
end
