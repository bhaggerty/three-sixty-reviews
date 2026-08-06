require "rails_helper"

RSpec.describe Reviews::ReminderJob do
  it "DMs the reviewer of each pending assignment in every active cycle" do
    manager = UserRepository.new.upsert(build(:user, slack_user_id: "U_MANAGER"))
    report = UserRepository.new.upsert(build(:user, slack_user_id: "U_REPORT", primary_manager_id: manager.id))
    active_cycle = ReviewCycleRepository.new.upsert(build(:review_cycle, status: "active"))
    ReviewAssignmentRepository.new.create(build(:review_assignment, cycle_id: active_cycle.id, reviewer_id: report.id, subject_id: manager.id, status: "pending"))

    draft_cycle = ReviewCycleRepository.new.upsert(build(:review_cycle, status: "draft"))
    ReviewAssignmentRepository.new.create(build(:review_assignment, cycle_id: draft_cycle.id, reviewer_id: manager.id, subject_id: report.id, status: "pending"))

    fake_web_api = instance_double(Slack::WebApiClient, chat_post_message: {})
    allow(Slack::WebApiClient).to receive(:new).and_return(fake_web_api)

    described_class.perform_now

    expect(fake_web_api).to have_received(:chat_post_message).with(channel: "U_REPORT", text: anything).once
  end

  it "skips a reviewer with no linked Slack identity instead of erroring" do
    manager = UserRepository.new.upsert(build(:user))
    report = UserRepository.new.upsert(build(:user, slack_user_id: nil, primary_manager_id: manager.id))
    cycle = ReviewCycleRepository.new.upsert(build(:review_cycle, status: "active"))
    ReviewAssignmentRepository.new.create(build(:review_assignment, cycle_id: cycle.id, reviewer_id: report.id, subject_id: manager.id, status: "pending"))

    fake_web_api = instance_double(Slack::WebApiClient, chat_post_message: {})
    allow(Slack::WebApiClient).to receive(:new).and_return(fake_web_api)

    expect { described_class.perform_now }.not_to raise_error
    expect(fake_web_api).not_to have_received(:chat_post_message)
  end

  it "does not message a reviewer whose assignment was already submitted" do
    manager = UserRepository.new.upsert(build(:user, slack_user_id: "U_MANAGER"))
    report = UserRepository.new.upsert(build(:user, slack_user_id: "U_REPORT", primary_manager_id: manager.id))
    cycle = ReviewCycleRepository.new.upsert(build(:review_cycle, status: "active"))
    ReviewAssignmentRepository.new.create(build(:review_assignment, cycle_id: cycle.id, reviewer_id: report.id, subject_id: manager.id, status: "submitted"))

    fake_web_api = instance_double(Slack::WebApiClient, chat_post_message: {})
    allow(Slack::WebApiClient).to receive(:new).and_return(fake_web_api)

    described_class.perform_now

    expect(fake_web_api).not_to have_received(:chat_post_message)
  end
end
