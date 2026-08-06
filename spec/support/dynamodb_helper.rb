RSpec.configure do |config|
  config.before do
    DynamoDbClient.client = FakeDynamoDbClient.new
  end

  config.after do
    DynamoDbClient.reset!
  end
end
