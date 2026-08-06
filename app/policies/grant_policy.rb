class GrantPolicy < ApplicationPolicy
  # The viewer a grant was made for can see that it exists; the admin can
  # see any grant.
  def show?
    user.admin? || record.viewer_id == user.id
  end

  # Creating/revoking grants directly (outside the share-request approval
  # flow) is admin-only.
  def manage?
    user.admin?
  end
end
