module Api
  module Slack
    # POST /slack/interactions -- handles both block_actions (the assignment
    # picker button) and view_submission (both stacked modal views), sharing
    # Reviews::SubmissionService with the web ReviewsController.
    class InteractionsController < BaseController
      def create
        case interaction_payload["type"]
        when "block_actions"
          handle_block_action
        when "view_submission"
          handle_view_submission
        else
          head :ok
        end
      end

      private

      def handle_block_action
        action = interaction_payload["actions"]&.first
        if action&.fetch("action_id", nil) == "pick_assignment"
          assignment = ReviewAssignmentRepository.new.find_by_id(action["value"])
          view = ::Slack::ModalBuilder.new.rating_view(private_metadata: assignment.id)
          ::Slack::WebApiClient.new.views_open(trigger_id: interaction_payload["trigger_id"], view: view)
        end
        head :ok
      end

      def handle_view_submission
        view = interaction_payload["view"]
        answers_so_far = ::Slack::AnswerExtractor.extract(view.dig("state", "values") || {})

        case view["callback_id"]
        when "review_ratings"
          push_freeform_view(view["private_metadata"], answers_so_far)
        when "review_freeform"
          finalize_submission(view["private_metadata"], answers_so_far)
        else
          head :ok
        end
      end

      def push_freeform_view(assignment_id, ratings)
        metadata = { assignment_id: assignment_id, ratings: ratings }.to_json
        next_view = ::Slack::ModalBuilder.new.freeform_view(private_metadata: metadata)
        render json: { response_action: "push", view: next_view }
      end

      def finalize_submission(metadata_json, freeform_answers)
        metadata = JSON.parse(metadata_json)
        assignment = ReviewAssignmentRepository.new.find_by_id(metadata["assignment_id"])
        answers = metadata["ratings"].merge(freeform_answers)

        Reviews::SubmissionService.new.submit(assignment: assignment, submitter_id: current_app_user.id, answers: answers)
        render json: {}
      rescue Reviews::SubmissionService::NotEligible, Reviews::SubmissionService::NotAssignedReviewer, Reviews::SubmissionService::AlreadyFinalized => e
        render json: { response_action: "errors", errors: { QuestionSet.freeform_questions.first[:id].to_s => submission_error_message(e) } }
      end

      def submission_error_message(error)
        case error
        when Reviews::SubmissionService::AlreadyFinalized then "This review has already been submitted."
        else "You're not eligible to submit this review."
        end
      end
    end
  end
end
