# Nested two levels deep (Admin::Reviews::) -- explicit `with:` required,
# same gotcha as ShareRequestsController.
module Admin
  module Reviews
    class GrantsController < ApplicationController
      def index
        authorize! Grant.new, with: GrantPolicy, to: :manage?
        @grants = GrantRepository.new.all
      end

      def revoke
        grant = GrantRepository.new.all.find { |g| g.id == params[:id] }
        render plain: "Not found", status: :not_found and return if grant.nil?

        authorize! grant, with: GrantPolicy, to: :manage?
        Sharing::GrantService.new.revoke(grant: grant, admin: current_user)
        redirect_to admin_reviews_grants_path, notice: "Revoked."
      end
    end
  end
end
