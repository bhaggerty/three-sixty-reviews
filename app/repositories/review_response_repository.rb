class ReviewResponseRepository < BaseRepository
  def find(assignment_id, id)
    ReviewResponse.from_item(get_item(ReviewKeys.assignment_key(assignment_id), ReviewKeys.response_key(id)))
  end

  def for_assignment(assignment_id)
    items = query(
      key_condition_expression: "pk = :pk AND begins_with(sk, :sk_prefix)",
      expression_attribute_values: {
        ":pk" => ReviewKeys.assignment_key(assignment_id),
        ":sk_prefix" => "RESPONSE#"
      }
    )
    items.map { |item| ReviewResponse.from_item(item) }
  end

  # Immutability of finalized responses is enforced by the caller
  # (Reviews::SubmissionService checks `finalized?` before allowing an edit)
  # rather than at the storage layer -- kept simple for v1, see plan's
  # "response editability" assumption.
  def save(response)
    put_item(response.to_item)
    response
  end
end
