class AuditLogRepository < BaseRepository
  def record(entry)
    put_item(entry.to_item)
    entry
  end

  def for_response(response_id)
    items = query(
      index_name: "GSI6",
      key_condition_expression: "gsi6pk = :pk",
      expression_attribute_values: { ":pk" => "TARGET##{ReviewKeys.share_request_key(response_id)}" }
    )
    items.map { |item| AuditLogEntry.from_item(item) }
  end
end
