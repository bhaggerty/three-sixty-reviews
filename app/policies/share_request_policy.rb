# `assignment` is optional context, needed only for #create? (the assignment
# behind the response being shared -- see ReviewResponsePolicy for why it's
# passed in rather than derived). #index?/#decide? are admin-only checks
# that don't concern any single assignment.
class ShareRequestPolicy < ApplicationPolicy
  authorize :assignment, optional: true

  # Either party in the underlying review pairing may request a share.
  def create?
    user.id == assignment.reviewer_id || user.id == assignment.subject_id
  end

  # Only the admin sees/decides the approval queue.
  def index?
    user.admin?
  end

  def decide?
    user.admin?
  end
end
