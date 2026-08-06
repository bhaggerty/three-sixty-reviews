require "rails_helper"

RSpec.describe OrgChart::ResyncService do
  let(:fake_client) { instance_double(OrgChart::Client) }
  subject(:service) { described_class.new(client: fake_client) }

  let(:manager_c1) { { "id" => "c1-mgr", "email" => "mgr@conductorone.com", "displayName" => "Manager Person", "managerIds" => [] } }
  let(:report_c1) { { "id" => "c1-report", "email" => "report@conductorone.com", "displayName" => "Report Person", "managerIds" => [ "c1-mgr" ] } }

  before do
    allow(fake_client).to receive(:list_users).with(page_token: nil).and_return(users: [ manager_c1, report_c1 ], next_page_token: nil)
  end

  it "creates a User row per ConductorOne user and resolves primary_manager_id across the two-pass linking" do
    service.resync!

    manager = UserRepository.new.find_by_conductor_one_id("c1-mgr")
    report = UserRepository.new.find_by_conductor_one_id("c1-report")

    expect(manager).not_to be_nil
    expect(report.primary_manager_id).to eq(manager.id)
  end

  it "links a pre-existing Slack-created user to their ConductorOne record by email instead of duplicating" do
    pre_existing = UserRepository.new.upsert(build(:user, slack_user_id: "U_REPORT", email: "report@conductorone.com", conductor_one_id: nil))

    service.resync!

    expect(UserRepository.new.all.size).to eq(2) # manager + the one pre-existing report, not 3
    linked = UserRepository.new.find(pre_existing.id)
    expect(linked.conductor_one_id).to eq("c1-report")
    expect(linked.slack_user_id).to eq("U_REPORT") # untouched -- resync doesn't know Slack ids
  end

  it "handles manager-before-report ordering correctly regardless of API page order" do
    allow(fake_client).to receive(:list_users).with(page_token: nil).and_return(users: [ report_c1, manager_c1 ], next_page_token: nil)

    service.resync!

    report = UserRepository.new.find_by_conductor_one_id("c1-report")
    manager = UserRepository.new.find_by_conductor_one_id("c1-mgr")
    expect(report.primary_manager_id).to eq(manager.id)
  end

  it "paginates through multiple pages" do
    allow(fake_client).to receive(:list_users).with(page_token: nil).and_return(users: [ manager_c1 ], next_page_token: "page2")
    allow(fake_client).to receive(:list_users).with(page_token: "page2").and_return(users: [ report_c1 ], next_page_token: nil)

    count = service.resync!

    expect(count).to eq(2)
    expect(UserRepository.new.find_by_conductor_one_id("c1-report").primary_manager_id).to eq(UserRepository.new.find_by_conductor_one_id("c1-mgr").id)
  end
end
