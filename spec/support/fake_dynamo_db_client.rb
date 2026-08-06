# A minimal in-memory stand-in for Aws::DynamoDB::Client, used in specs
# instead of Aws::DynamoDB::Client.new(stub_responses: true).
#
# stub_responses just returns canned data for every call, which can't verify
# that a repository's key_condition_expression actually finds what it just
# put. This fake implements real put/get/query/scan/delete semantics against
# an in-memory item store so repository specs exercise real query logic
# without needing DynamoDB Local, LocalStack, or Docker (none of which are
# available in this dev environment).
#
# Only supports the specific expression shapes this app's repositories
# actually issue -- it is not a general DynamoDB emulator.
class FakeDynamoDbClient
  Response = Struct.new(:item, :items, :last_evaluated_key, keyword_init: true)

  def initialize
    @items = {} # "pk|sk" => item hash
  end

  def put_item(table_name:, item:, condition_expression: nil, **)
    key = storage_key(item["pk"], item["sk"])

    if condition_expression&.include?("attribute_not_exists(pk)") && @items.key?(key)
      raise Aws::DynamoDB::Errors::ConditionalCheckFailedException.new(nil, "conditional check failed")
    end

    @items[key] = item.dup
    Response.new
  end

  def get_item(table_name:, key:, **)
    Response.new(item: @items[storage_key(key["pk"], key["sk"])])
  end

  def delete_item(table_name:, key:, **)
    @items.delete(storage_key(key["pk"], key["sk"]))
    Response.new
  end

  def query(table_name:, key_condition_expression:, expression_attribute_values:, index_name: nil, **)
    pk_attr = index_name ? "#{index_name.downcase}pk" : "pk"
    sk_attr = index_name ? "#{index_name.downcase}sk" : "sk"

    pk_value = expression_attribute_values.fetch(":pk")
    sk_prefix = expression_attribute_values[":sk_prefix"]

    matches = @items.values.select { |item| item[pk_attr] == pk_value }
    matches = matches.select { |item| item[sk_attr]&.start_with?(sk_prefix) } if sk_prefix
    matches = matches.sort_by { |item| item[sk_attr].to_s }

    Response.new(items: matches)
  end

  # Supports the specific filter_expression shapes this app's repositories
  # issue: "entity_type = :type" and "entity_type = :type AND id = :id".
  def scan(table_name:, filter_expression: nil, expression_attribute_values: {}, exclusive_start_key: nil, **)
    matches = @items.values

    if filter_expression&.include?("entity_type = :type")
      matches = matches.select { |item| item["entity_type"] == expression_attribute_values[":type"] }
    end

    if filter_expression&.include?("id = :id")
      matches = matches.select { |item| item["id"] == expression_attribute_values[":id"] }
    end

    Response.new(items: matches, last_evaluated_key: nil)
  end

  def list_tables
    Struct.new(:table_names).new([])
  end

  private

  def storage_key(pk, sk) = "#{pk}|#{sk}"
end
