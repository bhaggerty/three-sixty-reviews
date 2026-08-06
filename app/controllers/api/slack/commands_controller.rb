module Api
  module Slack
    # POST /slack/commands -- handles the /review slash command.
    class CommandsController < BaseController
      def create
        user = current_app_user
        return render(json: ephemeral("Please sign in at the web app first, then try /review again.")) if user.nil?

        assignments = ReviewAssignmentRepository.new.to_review_by(user.id, status: "pending")

        if assignments.empty?
          render json: ephemeral("Nothing pending right now.")
        elsif assignments.one?
          open_rating_modal(assignments.first, trigger_id: params[:trigger_id])
          head :ok
        else
          render json: picker_response(assignments)
        end
      end

      private

      def open_rating_modal(assignment, trigger_id:)
        view = ::Slack::ModalBuilder.new.rating_view(private_metadata: assignment.id)
        ::Slack::WebApiClient.new.views_open(trigger_id: trigger_id, view: view)
      end

      def picker_response(assignments)
        {
          response_type: "ephemeral",
          text: "Pick a review to fill out:",
          blocks: [ {
            type: "actions",
            block_id: "pick_assignment",
            elements: assignments.map { |a| assignment_button(a) }
          } ]
        }
      end

      def assignment_button(assignment)
        {
          type: "button",
          action_id: "pick_assignment",
          value: assignment.id,
          text: { type: "plain_text", text: assignment.upward? ? "Review your manager" : "Review your report" }
        }
      end

      def ephemeral(text)
        { response_type: "ephemeral", text: text }
      end
    end
  end
end
