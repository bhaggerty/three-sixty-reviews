# Nested two levels deep (Admin::Reviews::) -- per the known action_policy
# gotcha (see memory: feedback_action_policy_nested_namespace), bare
# authorize! fails to infer the policy class at this nesting depth and
# 500s. Every authorize! call here passes `with: ShareRequestPolicy`
# explicitly.
module Admin
  module Reviews
    class ShareRequestsController < ApplicationController
      before_action :set_share_request, only: [ :approve, :deny ]

      def index
        authorize! ShareRequest.new, with: ShareRequestPolicy, to: :index?
        @pending = ShareRequestRepository.new.pending_queue
      end

      def approve
        authorize! @share_request, with: ShareRequestPolicy, to: :decide?
        Sharing::GrantService.new.approve(share_request: @share_request, admin: current_user)
        redirect_to admin_reviews_share_requests_path, notice: "Approved."
      end

      def deny
        authorize! @share_request, with: ShareRequestPolicy, to: :decide?
        Sharing::GrantService.new.deny(share_request: @share_request, admin: current_user)
        redirect_to admin_reviews_share_requests_path, notice: "Denied."
      end

      private

      def set_share_request
        @share_request = ShareRequestRepository.new.for_response(params[:response_id]).find { |r| r.id == params[:id] } if params[:response_id]
        @share_request ||= find_pending_by_id(params[:id])
        render plain: "Not found", status: :not_found and return if @share_request.nil?
      end

      # The admin queue index lists requests without their response_id in
      # the URL, so approve/deny need to resolve a request by id alone.
      # Same small-scale-admin-tool justification as other id-only lookups.
      def find_pending_by_id(id)
        ShareRequestRepository.new.pending_queue.find { |r| r.id == id }
      end
    end
  end
end
