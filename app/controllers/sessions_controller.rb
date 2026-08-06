# "Sign in with Slack" is the sole identity system (see plan doc). First
# login for a given Slack identity creates a minimal User row; the
# reporting-line fields (conductor_one_id, primary_manager_id) get filled in
# by the next admin-triggered org-chart resync (OrgChart::ResyncService),
# not here.
class SessionsController < ApplicationController
  skip_before_action :require_login, only: [ :new, :create, :failure ]

  def new
  end

  def create
    auth = request.env["omniauth.auth"]
    repository = UserRepository.new
    user = repository.find_by_slack_id(auth.uid)

    # Falls back to matching a pre-provisioned row from an org-chart resync
    # (linked by email, since ConductorOne doesn't know Slack ids) before
    # creating a brand new user -- otherwise a resync-created row and this
    # person's real login would end up as two permanently-separate users.
    user ||= repository.find_by_email(auth.info.email)

    if user
      user.slack_user_id = auth.uid
      user.display_name = auth.info.name.presence || user.display_name
      repository.upsert(user)
    else
      user = repository.upsert(User.new(
        id: SecureRandom.uuid,
        slack_user_id: auth.uid,
        display_name: auth.info.name,
        email: auth.info.email
      ))
    end

    session[:user_id] = user.id
    redirect_to root_path
  end

  def failure
    render plain: "Sign-in failed: #{params[:message]}", status: :unauthorized
  end

  def destroy
    reset_session
    redirect_to sign_in_path
  end
end
