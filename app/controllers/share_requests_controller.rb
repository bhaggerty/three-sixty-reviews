# Nested one level under assignments (/assignments/:assignment_id/share_request)
# -- single-level nesting, bare authorize! infers ShareRequestPolicy fine.
class ShareRequestsController < ApplicationController
  def create
    assignment = ReviewAssignmentRepository.new.find_by_id(params[:assignment_id])
    render plain: "Not found", status: :not_found and return if assignment.nil?

    response = ReviewResponseRepository.new.for_assignment(assignment.id).first
    render plain: "Not found", status: :not_found and return if response.nil?

    authorize! ShareRequest.new, context: { assignment: assignment }, to: :create?

    # The reviewer (owner) always already has access to their own writing
    # (ReviewResponsePolicy#show_content?'s owner? check) -- the subject
    # never does automatically. So the grant this produces always targets
    # the subject, regardless of which of the two parties clicked "share":
    # the reviewer sharing their own writing, or the subject asking to see
    # what was written about them, both resolve to the same target.
    Sharing::ShareRequestService.new.request_share(
      response_id: response.id,
      requested_by_id: current_user.id,
      target_viewer_id: assignment.subject_id
    )
    redirect_to assignment_path(assignment.id), notice: "Share request submitted for admin approval."
  end
end
