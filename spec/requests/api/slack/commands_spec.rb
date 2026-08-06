require "rails_helper"

RSpec.describe "Api::Slack::Commands", type: :request do
  let(:user) { build(:user, slack_user_id: "U_SLACK") }
  let(:manager) { build(:user) }

  before { UserRepository.new.upsert(user) }

  it "rejects a request with an invalid signature (not a session/CSRF check -- the Slack signature itself)" do
    post "/slack/commands", params: { command: "/review", user_id: "U_SLACK" }, headers: {
      "X-Slack-Request-Timestamp" => Time.now.to_i.to_s,
      "X-Slack-Signature" => "v0=not-a-real-signature"
    }

    expect(response).to have_http_status(:unauthorized)
  end

  it "tells an unknown Slack user to sign in on the web app first" do
    post_signed_slack("/slack/commands", command: "/review", user_id: "U_UNKNOWN")

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["text"]).to include("sign in")
  end

  it "responds that nothing is pending when there are no assignments" do
    post_signed_slack("/slack/commands", command: "/review", user_id: "U_SLACK")

    expect(JSON.parse(response.body)["text"]).to include("Nothing pending")
  end

  it "opens a modal directly when there is exactly one pending assignment" do
    UserRepository.new.upsert(manager)
    assignment = ReviewAssignmentRepository.new.create(build(:review_assignment, reviewer_id: user.id, subject_id: manager.id, direction: "up"))

    fake_web_api = instance_double(Slack::WebApiClient, views_open: {})
    allow(Slack::WebApiClient).to receive(:new).and_return(fake_web_api)

    post_signed_slack("/slack/commands", command: "/review", user_id: "U_SLACK", trigger_id: "trigger-123")

    expect(response).to have_http_status(:ok)
    expect(fake_web_api).to have_received(:views_open).with(trigger_id: "trigger-123", view: hash_including(private_metadata: assignment.id))
  end

  it "offers a picker when there are multiple pending assignments" do
    UserRepository.new.upsert(manager)
    other_manager = UserRepository.new.upsert(build(:user))
    ReviewAssignmentRepository.new.create(build(:review_assignment, reviewer_id: user.id, subject_id: manager.id, direction: "up"))
    ReviewAssignmentRepository.new.create(build(:review_assignment, reviewer_id: user.id, subject_id: other_manager.id, direction: "up"))

    post_signed_slack("/slack/commands", command: "/review", user_id: "U_SLACK")

    body = JSON.parse(response.body)
    expect(body["blocks"].first["elements"].size).to eq(2)
  end
end
