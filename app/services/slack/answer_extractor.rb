module Slack
  # Flattens Slack's view.state.values shape (block_id => { action_id =>
  # { value: ... } | { selected_option: { value: ... } } }) into a plain
  # { question_id => answer } hash, matching what Reviews::SubmissionService
  # expects from the web form.
  class AnswerExtractor
    def self.extract(state_values)
      state_values.each_with_object({}) do |(block_id, actions), answers|
        action = actions["value"]
        next if action.nil?

        answers[block_id] = action.dig("selected_option", "value") || action["value"]
      end
    end
  end
end
