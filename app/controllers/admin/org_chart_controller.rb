module Admin
  # No natural policy record for a singleton admin action with no resource
  # -- a direct admin? check is simpler and just as correct here than
  # forcing this through action_policy.
  class OrgChartController < ApplicationController
    def resync
      return render_forbidden unless current_user.admin?

      count = OrgChart::ResyncService.new.resync!
      redirect_to root_path, notice: "Resynced #{count} users from ConductorOne."
    end
  end
end
