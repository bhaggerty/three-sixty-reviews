RSpec.configure do |config|
  config.before do
    KmsClient.client = FakeKmsClient.new
  end

  config.after do
    KmsClient.reset!
  end
end
