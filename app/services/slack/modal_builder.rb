module Slack
  # Builds the two stacked Block Kit views for the /review slash command
  # flow: View 1 collects the 5 rating questions (radio_buttons 1-5), then
  # response_action: "push" advances to View 2 for the 3 freeform
  # questions (multiline plain_text_input). Well under Slack's 100-block
  # ceiling; the real constraint is Slack's ~3000-char cap per text field.
  class ModalBuilder
    def rating_view(private_metadata:)
      {
        type: "modal",
        callback_id: "review_ratings",
        private_metadata: private_metadata,
        title: { type: "plain_text", text: "Review: ratings" },
        submit: { type: "plain_text", text: "Next" },
        blocks: QuestionSet.rating_questions.map { |q| rating_block(q) }
      }
    end

    def freeform_view(private_metadata:)
      {
        type: "modal",
        callback_id: "review_freeform",
        private_metadata: private_metadata,
        title: { type: "plain_text", text: "Review: comments" },
        submit: { type: "plain_text", text: "Submit" },
        blocks: QuestionSet.freeform_questions.map { |q| freeform_block(q) }
      }
    end

    private

    def rating_block(question)
      {
        type: "input",
        block_id: question[:id].to_s,
        label: { type: "plain_text", text: question[:prompt] },
        element: {
          type: "radio_buttons",
          action_id: "value",
          options: (1..5).map { |n| { text: { type: "plain_text", text: n.to_s }, value: n.to_s } }
        }
      }
    end

    def freeform_block(question)
      {
        type: "input",
        block_id: question[:id].to_s,
        label: { type: "plain_text", text: question[:prompt] },
        element: { type: "plain_text_input", action_id: "value", multiline: true }
      }
    end
  end
end
