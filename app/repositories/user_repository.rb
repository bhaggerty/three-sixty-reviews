class UserRepository < BaseRepository
  def find(id)
    User.from_item(get_item(ReviewKeys.user_key(id), ReviewKeys.user_key(id)))
  end

  def find_by_slack_id(slack_user_id)
    items = query(
      index_name: ReviewKeys::GSI1_SLACK_LOOKUP,
      key_condition_expression: "gsi1pk = :pk",
      expression_attribute_values: { ":pk" => ReviewKeys.slack_key(slack_user_id) }
    )
    User.from_item(items.first)
  end

  # No email/conductor_one_id GSIs -- correlating ConductorOne users to
  # pre-existing Slack logins is a low-frequency admin action (org-chart
  # resync), so reusing the same #all scan as everything else here is fine.
  def find_by_email(email)
    return nil if email.blank?
    all.find { |u| u.email&.casecmp?(email) }
  end

  def find_by_conductor_one_id(conductor_one_id)
    return nil if conductor_one_id.blank?
    all.find { |u| u.conductor_one_id == conductor_one_id }
  end

  def upsert(user)
    put_item(user.to_item)
    user
  end

  # Scan is acceptable here: this is a small-company internal tool (not a
  # high-scale multi-tenant table), and this is the only place the app needs
  # "every user" rather than a keyed lookup -- org-chart resync and
  # assignment generation, both low-frequency admin actions.
  def all
    items = []
    last_evaluated_key = nil

    loop do
      params = {
        table_name: table_name,
        filter_expression: "entity_type = :type",
        expression_attribute_values: { ":type" => "USER" }
      }
      params[:exclusive_start_key] = last_evaluated_key if last_evaluated_key

      resp = client.scan(**params)
      items.concat(resp.items)
      last_evaluated_key = resp.last_evaluated_key
      break if last_evaluated_key.nil? || last_evaluated_key.empty?
    end

    items.map { |item| User.from_item(item) }
  end
end
