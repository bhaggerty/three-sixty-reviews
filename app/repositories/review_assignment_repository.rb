class ReviewAssignmentRepository < BaseRepository
  def find(cycle_id, id)
    ReviewAssignment.from_item(get_item(ReviewKeys.cycle_key(cycle_id), ReviewKeys.assignment_key(id)))
  end

  # Routes only carry the assignment id (not its cycle_id) -- see
  # controllers -- so this resolves an assignment id-only via Scan. Same
  # small-internal-tool justification as UserRepository#all: this app is a
  # handful of cycles/assignments, not a high-scale table.
  def find_by_id(id)
    resp = client.scan(
      table_name: table_name,
      filter_expression: "entity_type = :type AND id = :id",
      expression_attribute_values: { ":type" => "REVIEW_ASSIGNMENT", ":id" => id }
    )
    ReviewAssignment.from_item(resp.items.first)
  end

  # ensure_new: true makes cycle-kickoff assignment generation idempotent --
  # re-running it for the same (cycle, reviewer, subject, direction) id is a
  # no-op rather than clobbering an in-progress or submitted assignment.
  def create(assignment)
    put_item(assignment.to_item, ensure_new: true)
    assignment
  rescue BaseRepository::ConditionalWriteFailed
    find(assignment.cycle_id, assignment.id)
  end

  def save(assignment)
    put_item(assignment.to_item)
    assignment
  end

  def for_cycle(cycle_id)
    items = query(
      key_condition_expression: "pk = :pk AND begins_with(sk, :sk_prefix)",
      expression_attribute_values: {
        ":pk" => ReviewKeys.cycle_key(cycle_id),
        ":sk_prefix" => "ASSIGNMENT#"
      }
    )
    items.map { |item| ReviewAssignment.from_item(item) }
  end

  # "Reviews I need to write" -- GSI2 is keyed by reviewer_id.
  def to_review_by(user_id, status: nil)
    sk_prefix = status ? ReviewKeys.role_prefix(role: "REVIEWER") + "STATUS##{status}#" : ReviewKeys.role_prefix(role: "REVIEWER")
    items = query(
      index_name: ReviewKeys::GSI2_BY_USER_ROLE,
      key_condition_expression: "gsi2pk = :pk AND begins_with(gsi2sk, :sk_prefix)",
      expression_attribute_values: { ":pk" => ReviewKeys.user_key(user_id), ":sk_prefix" => sk_prefix }
    )
    items.map { |item| ReviewAssignment.from_item(item) }
  end

  # "Reviews about me" -- GSI4 is keyed by subject_id. Named GSI4 (not GSI3,
  # which is reserved for the admin share queue) and not GSI2 (reserved for
  # the reviewer-keyed index above) -- see ReviewAssignment's to_item comment
  # for why one item needs two separate GSIs to serve both access patterns.
  def about(user_id, status: nil)
    sk_prefix = status ? ReviewKeys.role_prefix(role: "SUBJECT") + "STATUS##{status}#" : ReviewKeys.role_prefix(role: "SUBJECT")
    items = query(
      index_name: "GSI4",
      key_condition_expression: "gsi4pk = :pk AND begins_with(gsi4sk, :sk_prefix)",
      expression_attribute_values: { ":pk" => ReviewKeys.user_key(user_id), ":sk_prefix" => sk_prefix }
    )
    items.map { |item| ReviewAssignment.from_item(item) }
  end
end
