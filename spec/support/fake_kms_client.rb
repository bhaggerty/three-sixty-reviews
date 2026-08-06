# In-memory stand-in for Aws::KMS::Client (no real AWS/LocalStack available
# in this dev environment -- see fake_dynamo_db_client.rb for the same
# rationale). Mirrors real KMS's actual security property that matters for
# these specs: encryption_context is cryptographically bound to the wrapped
# data key, so Decrypt with a different context than GenerateDataKey used
# raises InvalidCiphertextException instead of unwrapping.
class FakeKmsClient
  DataKeyResponse = Struct.new(:plaintext, :ciphertext_blob, :key_id, keyword_init: true)
  DecryptResponse = Struct.new(:plaintext, :key_id, keyword_init: true)

  def initialize
    @wrapped_keys = {}
  end

  def generate_data_key(key_id:, key_spec:, encryption_context: {})
    plaintext_key = SecureRandom.random_bytes(32)
    ciphertext_blob = SecureRandom.random_bytes(32)

    @wrapped_keys[ciphertext_blob] = { plaintext_key: plaintext_key, encryption_context: encryption_context, key_id: key_id }

    DataKeyResponse.new(plaintext: plaintext_key, ciphertext_blob: ciphertext_blob, key_id: key_id)
  end

  def decrypt(ciphertext_blob:, encryption_context: {})
    wrapped = @wrapped_keys[ciphertext_blob]

    if wrapped.nil? || wrapped[:encryption_context] != encryption_context
      raise Aws::KMS::Errors::InvalidCiphertextException.new(nil, "encryption context mismatch")
    end

    DecryptResponse.new(plaintext: wrapped[:plaintext_key], key_id: wrapped[:key_id])
  end
end
