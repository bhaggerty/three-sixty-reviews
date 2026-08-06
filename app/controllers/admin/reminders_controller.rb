module Admin
  class RemindersController < ApplicationController
    def create
      return render_forbidden unless current_user.admin?

      ::Reviews::ReminderJob.perform_later
      redirect_back fallback_location: root_path, notice: "Reminders queued."
    end
  end
end
