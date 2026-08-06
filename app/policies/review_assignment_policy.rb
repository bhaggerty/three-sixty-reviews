class ReviewAssignmentPolicy < ApplicationPolicy
  def show?
    user.admin? || own_assignment?
  end

  def submit?
    record.reviewer_id == user.id
  end

  private

  def own_assignment?
    record.reviewer_id == user.id || record.subject_id == user.id
  end
end
