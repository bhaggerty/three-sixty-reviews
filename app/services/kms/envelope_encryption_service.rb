module Kms
  # Envelope encryption: KMS generates a one-time data key wrapped by a CMK,
  # we do the actual AES-256-GCM encryption locally with the unwrapped key,
  # and store only the wrapped (still-encrypted) data key alongside the
  # ciphertext. Decrypting requires KMS to unwrap the data key, which KMS
  # will only do for principals its key policy allows -- see plan doc:
  # "no infra access to plaintext" relies on that key policy, not on
  # anything in this class.
  #
  # `encryption_context` is passed to KMS on both GenerateDataKey and
  # Decrypt; KMS cryptographically binds it to the wrapped key, so a
  # mismatched context on decrypt raises Aws::KMS::Errors::InvalidCiphertextException
  # rather than silently succeeding. It is also passed to OpenSSL as AES-GCM
  # additional authenticated data, binding it at the local decrypt step too.
  #
  # IMPORTANT: never put identity (submitter/reviewer id) in
  # encryption_context for anything anonymity-sensitive -- KMS logs
  # encryption_context to CloudTrail in plaintext.
  class EnvelopeEncryptionService
    class DecryptionFailed < StandardError; end

    def initialize(client: KmsClient.client)
      @client = client
    end

    def encrypt(plaintext, context:, key_alias:)
      data_key_resp = client.generate_data_key(key_id: key_alias, key_spec: "AES_256", encryption_context: context)
      plaintext_key = data_key_resp.plaintext

      cipher = OpenSSL::Cipher.new("aes-256-gcm")
      cipher.encrypt
      cipher.key = plaintext_key
      iv = cipher.random_iv
      cipher.auth_data = aad(context)
      ciphertext = cipher.update(plaintext.to_s) + cipher.final
      auth_tag = cipher.auth_tag

      {
        "ciphertext" => Base64.strict_encode64(ciphertext),
        "iv" => Base64.strict_encode64(iv),
        "auth_tag" => Base64.strict_encode64(auth_tag),
        "encrypted_data_key" => Base64.strict_encode64(data_key_resp.ciphertext_blob),
        "kms_key_id" => data_key_resp.key_id,
        "encryption_context" => context
      }
    ensure
      plaintext_key = nil
    end

    def decrypt(envelope, context:)
      encrypted_data_key = Base64.strict_decode64(envelope.fetch("encrypted_data_key"))
      data_key_resp = client.decrypt(ciphertext_blob: encrypted_data_key, encryption_context: context)
      plaintext_key = data_key_resp.plaintext

      cipher = OpenSSL::Cipher.new("aes-256-gcm")
      cipher.decrypt
      cipher.key = plaintext_key
      cipher.iv = Base64.strict_decode64(envelope.fetch("iv"))
      cipher.auth_tag = Base64.strict_decode64(envelope.fetch("auth_tag"))
      cipher.auth_data = aad(context)
      cipher.update(Base64.strict_decode64(envelope.fetch("ciphertext"))) + cipher.final
    rescue Aws::KMS::Errors::InvalidCiphertextException => e
      raise DecryptionFailed, "encryption context mismatch or corrupted ciphertext: #{e.message}"
    ensure
      plaintext_key = nil
    end

    private

    attr_reader :client

    def aad(context)
      context.sort.to_h.to_json
    end
  end
end
