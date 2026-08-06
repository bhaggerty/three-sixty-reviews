class GrantRepository < BaseRepository
  def find(response_id, scope, viewer_id)
    Grant.from_item(get_item(ReviewKeys.share_request_key(response_id), ReviewKeys.grant_key(scope, viewer_id)))
  end

  def create(grant)
    put_item(grant.to_item, ensure_new: true)
    grant
  rescue BaseRepository::ConditionalWriteFailed
    find(grant.response_id, grant.scope, grant.viewer_id)
  end

  def save(grant)
    put_item(grant.to_item)
    grant
  end

  def for_response(response_id)
    items = query(
      key_condition_expression: "pk = :pk AND begins_with(sk, :sk_prefix)",
      expression_attribute_values: {
        ":pk" => ReviewKeys.share_request_key(response_id),
        ":sk_prefix" => "GRANT#"
      }
    )
    items.map { |item| Grant.from_item(item) }
  end

  def for_viewer(viewer_id)
    items = query(
      index_name: "GSI5",
      key_condition_expression: "gsi5pk = :pk",
      expression_attribute_values: { ":pk" => "#{ReviewKeys.user_key(viewer_id)}#GRANTS" }
    )
    items.map { |item| Grant.from_item(item) }
  end

  def active?(response_id, scope, viewer_id)
    grant = find(response_id, scope, viewer_id)
    !grant.nil? && grant.active?
  end

  # Admin-only visibility across every grant ever issued. Same small-scale
  # scan justification as UserRepository#all.
  def all
    resp = client.scan(
      table_name: table_name,
      filter_expression: "entity_type = :type",
      expression_attribute_values: { ":type" => "GRANT" }
    )
    resp.items.map { |item| Grant.from_item(item) }
  end
end
