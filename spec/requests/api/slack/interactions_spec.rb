require "rails_helper"

RSpec.describe "Api::Slack::Interactions", type: :request do
  let(:manager) { UserRepository.new.upsert(build(:user)) }
  let(:user) { UserRepository.new.upsert(build(:user, slack_user_id: "U_SLACK", primary_manager_id: manager.id)) }
  let(:assignment) { ReviewAssignmentRepository.new.create(build(:review_assignment, reviewer_id: user.id, subject_id: manager.id, direction: "up")) }

  def post_interaction(payload)
    post_signed_slack("/slack/interactions", payload: payload.to_json)
  end

  describe "block_actions (assignment picker)" do
    it "opens the rating modal for the picked assignment" do
      fake_web_api = instance_double(Slack::WebApiClient, views_open: {})
      allow(Slack::WebApiClient).to receive(:new).and_return(fake_web_api)

      post_interaction(
        "type" => "block_actions",
        "trigger_id" => "trigger-abc",
        "user" => { "id" => "U_SLACK" },
        "actions" => [ { "action_id" => "pick_assignment", "value" => assignment.id } ]
      )

      expect(response).to have_http_status(:ok)
      expect(fake_web_api).to have_received(:views_open).with(trigger_id: "trigger-abc", view: hash_including(private_metadata: assignment.id))
    end
  end

  describe "view_submission" do
    it "pushes the freeform view after the ratings view, carrying ratings forward in private_metadata" do
      post_interaction(
        "type" => "view_submission",
        "user" => { "id" => "U_SLACK" },
        "view" => {
          "callback_id" => "review_ratings",
          "private_metadata" => assignment.id,
          "state" => { "values" => { "q1_communication" => { "value" => { "selected_option" => { "value" => "5" } } } } }
        }
      )

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["response_action"]).to eq("push")
      metadata = JSON.parse(body["view"]["private_metadata"])
      expect(metadata["assignment_id"]).to eq(assignment.id)
      expect(metadata["ratings"]).to eq("q1_communication" => "5")
    end

    it "finalizes the submission on the freeform view, merging ratings and freeform answers" do
      metadata = { assignment_id: assignment.id, ratings: { "q1_communication" => "5" } }.to_json

      post_interaction(
        "type" => "view_submission",
        "user" => { "id" => "U_SLACK" },
        "view" => {
          "callback_id" => "review_freeform",
          "private_metadata" => metadata,
          "state" => { "values" => { "q6_strengths" => { "value" => { "value" => "Great mentor." } } } }
        }
      )

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq("{}")

      saved = ReviewResponseRepository.new.for_assignment(assignment.id).first
      expect(saved).to be_finalized
      answers = Crypto::ResponseEncryptor.new.decrypt_answers(saved.answers_envelope, response_id: saved.id)
      expect(answers).to eq("q1_communication" => "5", "q6_strengths" => "Great mentor.")
    end

    it "returns a view_submission error instead of a 500 when the submitter isn't eligible" do
      stranger = UserRepository.new.upsert(build(:user, slack_user_id: "U_STRANGER"))
      metadata = { assignment_id: assignment.id, ratings: {} }.to_json

      post_interaction(
        "type" => "view_submission",
        "user" => { "id" => "U_STRANGER" },
        "view" => {
          "callback_id" => "review_freeform",
          "private_metadata" => metadata,
          "state" => { "values" => {} }
        }
      )

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["response_action"]).to eq("errors")
    end
  end
end
