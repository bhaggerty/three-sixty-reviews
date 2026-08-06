# Thin wrapper around the AWS KMS client, mirroring DynamoDbClient. Union
# Station injects AWS credentials via the instance role; the two CMK
# aliases (alias/review-content, alias/review-attestation) are provisioned
# out-of-band with key policies scoped to this app's IAM role only -- see
# plan doc's encryption/key-custody section.
class KmsClient
  class << self
    def client
      @client ||= Aws::KMS::Client.new(region: ENV.fetch("AWS_REGION", "us-west-2"))
    end

    attr_writer :client

    def reset!
      @client = nil
    end
  end
end
