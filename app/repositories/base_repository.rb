class BaseRepository
  class ConditionalWriteFailed < StandardError; end

  def initialize(client: DynamoDbClient.client, table_name: DynamoDbClient.table_name)
    @client = client
    @table_name = table_name
  end

  private

  attr_reader :client, :table_name

  def put_item(item, ensure_new: false)
    params = { table_name: table_name, item: item }
    params[:condition_expression] = "attribute_not_exists(pk) AND attribute_not_exists(sk)" if ensure_new
    client.put_item(**params)
    item
  rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
    raise ConditionalWriteFailed, "item already exists for pk=#{item['pk']} sk=#{item['sk']}"
  end

  def get_item(pk, sk)
    resp = client.get_item(table_name: table_name, key: { "pk" => pk, "sk" => sk })
    resp.item
  end

  def query(**params)
    client.query(**params.merge(table_name: table_name)).items
  end

  def delete_item(pk, sk)
    client.delete_item(table_name: table_name, key: { "pk" => pk, "sk" => sk })
  end
end
