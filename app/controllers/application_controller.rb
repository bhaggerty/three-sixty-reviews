class ApplicationController < ActionController::Base
  include ActionPolicy::Controller

  authorize :user, through: :current_user

  before_action :require_login
  helper_method :current_user

  rescue_from ActionPolicy::Unauthorized, with: :render_forbidden

  private

  def current_user
    @current_user ||= session[:user_id] && UserRepository.new.find(session[:user_id])
  end

  def require_login
    redirect_to sign_in_path unless current_user
  end

  def render_forbidden
    render plain: "Forbidden", status: :forbidden
  end
end
