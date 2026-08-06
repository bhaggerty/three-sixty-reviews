# Thin wrapper around the single DynamoDB client/table this app uses.
#
# Union Station injects APP_DYNAMODB_TABLE_NAME and AWS credentials via the
# instance role at runtime (see memory: reference_union_station). Locally/in
# tests, DYNAMODB_ENDPOINT can point at a local DynamoDB, or specs can inject
# a stubbed Aws::DynamoDB::Client directly via `DynamoDbClient.client=`.
class DynamoDbClient
  class << self
    def client
      @client ||= Aws::DynamoDB::Client.new(client_options)
    end

    attr_writer :client

    def table_name
      ENV.fetch("APP_DYNAMODB_TABLE_NAME", "three_sixty_reviews_#{Rails.env}")
    end

    def reset!
      @client = nil
    end

    private

    def client_options
      options = { region: ENV.fetch("AWS_REGION", "us-west-2") }
      options[:endpoint] = ENV["DYNAMODB_ENDPOINT"] if ENV["DYNAMODB_ENDPOINT"].present?
      options
    end
  end
end
