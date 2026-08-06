require "rails_helper"

# Exercises the full path from the plan doc's verification section: resync
# org chart -> kick off a cycle -> submit one review via the web app and
# one via a simulated Slack view_submission -> request a share -> admin
# approves -> confirm the recipient can now decrypt content but the
# attestation (who really wrote it) stays admin-only even after approval.
RSpec.describe "End-to-end review flow", type: :request do
  let(:admin) { UserRepository.new.upsert(build(:user, :admin)) }

  it "composes org-chart resync through share approval correctly" do
    # 1. Org-chart resync creates the manager/report relationship.
    manager_c1 = { "id" => "c1-mgr", "email" => "mgr@conductorone.com", "displayName" => "Manager", "managerIds" => [] }
    report_c1 = { "id" => "c1-report", "email" => "report@conductorone.com", "displayName" => "Report", "managerIds" => [ "c1-mgr" ] }
    fake_client = instance_double(OrgChart::Client, list_users: { users: [ manager_c1, report_c1 ], next_page_token: nil })
    OrgChart::ResyncService.new(client: fake_client).resync!

    manager = UserRepository.new.find_by_conductor_one_id("c1-mgr")
    report = UserRepository.new.find_by_conductor_one_id("c1-report")
    manager.slack_user_id = "U_MANAGER"
    report.slack_user_id = "U_REPORT"
    UserRepository.new.upsert(manager)
    UserRepository.new.upsert(report)
    expect(report.primary_manager_id).to eq(manager.id)

    # 2. Kick off a cycle -- generates one "up" and one "down" assignment.
    cycle = ReviewCycleRepository.new.upsert(build(:review_cycle, status: "draft"))
    Reviews::CycleKickoffJob.perform_now(cycle.id)
    up_assignment = ReviewAssignmentRepository.new.to_review_by(report.id, status: "pending").first
    down_assignment = ReviewAssignmentRepository.new.to_review_by(manager.id, status: "pending").first
    expect(up_assignment.direction).to eq("up")
    expect(down_assignment.direction).to eq("down")

    # 3. Report submits their upward review via the web app.
    sign_in(report)
    post assignment_response_path(up_assignment.id), params: { answers: { "q1_communication" => "5" } }
    expect(response).to redirect_to(assignments_path)

    # 4. Manager submits their downward review via a simulated Slack modal flow.
    stub_valid_slack_signature!
    post "/slack/interactions", params: { payload: {
      type: "view_submission",
      user: { id: "U_MANAGER" },
      view: {
        callback_id: "review_ratings",
        private_metadata: down_assignment.id,
        state: { values: { "q1_communication" => { "value" => { "selected_option" => { "value" => "4" } } } } }
      }
    }.to_json }
    ratings_metadata = JSON.parse(response.body)["view"]["private_metadata"]

    post "/slack/interactions", params: { payload: {
      type: "view_submission",
      user: { id: "U_MANAGER" },
      view: {
        callback_id: "review_freeform",
        private_metadata: ratings_metadata,
        state: { values: { "q6_strengths" => { "value" => { "value" => "Solid work this cycle." } } } }
      }
    }.to_json }
    expect(response.body).to eq("{}")

    down_response = ReviewResponseRepository.new.for_assignment(down_assignment.id).first
    expect(down_response).to be_finalized

    # 5. Report (recipient of the downward review) requests to see it.
    sign_in(report)
    post assignment_share_request_path(down_assignment.id)
    expect(response).to redirect_to(assignment_path(down_assignment.id))

    share_request = ShareRequestRepository.new.pending_queue.find { |r| r.response_id == down_response.id }
    expect(share_request).not_to be_nil
    expect(GrantRepository.new.for_response(down_response.id)).to be_empty # not unlocked yet -- admin hasn't acted

    # 6. Admin approves.
    sign_in(admin)
    post approve_admin_reviews_share_request_path(share_request.id)
    expect(response).to redirect_to(admin_reviews_share_requests_path)

    # 7. The recipient can now decrypt content, but never the attestation --
    # even after approval, even as the person the review was about.
    content_policy = ReviewResponsePolicy.new(down_response, user: report, assignment: down_assignment)
    expect(content_policy.show_content?).to be true
    expect(content_policy.show_attestation?).to be false

    admin_policy = ReviewResponsePolicy.new(down_response, user: admin, assignment: down_assignment)
    expect(admin_policy.show_attestation?).to be true

    encryptor = Crypto::ResponseEncryptor.new
    answers = encryptor.decrypt_answers(down_response.answers_envelope, response_id: down_response.id)
    expect(answers).to eq("q1_communication" => "4", "q6_strengths" => "Solid work this cycle.")

    attestation = encryptor.decrypt_attestation(down_response.attestation_envelope, response_id: down_response.id)
    expect(attestation["submitter_user_id"]).to eq(manager.id) # only ever readable by/for the admin's flow, never exposed to report
  end
end
