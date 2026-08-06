# Requires `assignment` in the authorization context, e.g.
#   authorize! response, with: ReviewResponsePolicy, context: { assignment: @assignment }
# (see plan doc: a ReviewResponse only stores assignment_id, and looking
# that up requires the assignment's cycle_id too, which the response doesn't
# have -- callers always already have @assignment loaded from the route, so
# it's passed in rather than re-derived here).
class ReviewResponsePolicy < ApplicationPolicy
  authorize :assignment

  # The submitter can always see their own written answers. The recipient
  # can see them only with an active CONTENT grant -- never automatically.
  def show_content?
    user.admin? || owner? || active_content_grant?
  end

  # Attestation (who really submitted this) is never visible to anyone but
  # the admin -- not even via a Grant. There is deliberately no grant-based
  # path here; see Sharing::GrantService, which never creates ATTESTATION
  # scope grants.
  def show_attestation?
    user.admin?
  end

  private

  def owner?
    assignment.reviewer_id == user.id
  end

  def active_content_grant?
    GrantRepository.new.active?(record.id, "CONTENT", user.id)
  end
end
