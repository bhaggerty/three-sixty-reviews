class ReviewCycleRepository < BaseRepository
  def find(id)
    ReviewCycle.from_item(get_item(ReviewKeys.cycle_key(id), ReviewKeys.cycle_key(id)))
  end

  def upsert(cycle)
    put_item(cycle.to_item)
    cycle
  end

  # Low-frequency, small-cardinality entity (a handful of cycles ever) --
  # scan is fine, same reasoning as UserRepository#all.
  def all
    resp = client.scan(
      table_name: table_name,
      filter_expression: "entity_type = :type",
      expression_attribute_values: { ":type" => "REVIEW_CYCLE" }
    )
    resp.items.map { |item| ReviewCycle.from_item(item) }
  end
end
