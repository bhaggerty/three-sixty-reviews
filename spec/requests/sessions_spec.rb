require "rails_helper"

RSpec.describe "Sessions (Sign in with Slack)", type: :request do
  before do
    OmniAuth.config.test_mode = true
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:slack] = nil
  end

  def mock_slack_auth(uid:, email:, name:)
    OmniAuth.config.mock_auth[:slack] = OmniAuth::AuthHash.new(
      provider: "slack",
      uid: uid,
      info: { email: email, name: name }
    )
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:slack]
  end

  it "creates a brand new user on a first-ever login" do
    mock_slack_auth(uid: "U_NEW", email: "new@conductorone.com", name: "New Person")

    get "/auth/slack/callback"

    user = UserRepository.new.find_by_slack_id("U_NEW")
    expect(user).not_to be_nil
    expect(user.display_name).to eq("New Person")
    expect(response).to redirect_to(root_path)
  end

  it "links a pre-provisioned (resync-created, not-yet-signed-in) user by email instead of duplicating" do
    pre_existing = UserRepository.new.upsert(build(:user, slack_user_id: nil, email: "pending@conductorone.com", conductor_one_id: "c1-1"))
    mock_slack_auth(uid: "U_LINKED", email: "pending@conductorone.com", name: "Pending Person")

    get "/auth/slack/callback"

    expect(UserRepository.new.all.size).to eq(1)
    linked = UserRepository.new.find(pre_existing.id)
    expect(linked.slack_user_id).to eq("U_LINKED")
    expect(linked.conductor_one_id).to eq("c1-1") # untouched
  end

  it "finds an existing fully-linked user by slack id on repeat logins, without creating a duplicate" do
    existing = UserRepository.new.upsert(build(:user, slack_user_id: "U_REPEAT"))
    mock_slack_auth(uid: "U_REPEAT", email: existing.email, name: existing.display_name)

    get "/auth/slack/callback"

    expect(UserRepository.new.all.size).to eq(1)
  end
end
