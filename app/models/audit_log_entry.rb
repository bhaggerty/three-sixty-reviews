class AuditLogEntry
  include ActiveModel::Model
  include ActiveModel::Attributes

  ACTIONS = %w[grant_created grant_revoked share_requested share_approved share_denied content_decrypted attestation_decrypted].freeze

  attribute :id, :string
  attribute :action, :string
  attribute :response_id, :string
  attribute :actor_id, :string
  attribute :target_viewer_id, :string
  attribute :metadata, default: -> { {} }
  attribute :occurred_at, :datetime

  validates :id, :action, :response_id, :actor_id, presence: true
  validates :action, inclusion: { in: ACTIONS }

  def self.from_item(item)
    return nil if item.nil?

    new(
      id: item["id"],
      action: item["action"],
      response_id: item["response_id"],
      actor_id: item["actor_id"],
      target_viewer_id: item["target_viewer_id"],
      metadata: item["metadata"] || {},
      occurred_at: item["occurred_at"] && Time.iso8601(item["occurred_at"])
    )
  end

  def to_item
    occurred = occurred_at || Time.current
    {
      "pk" => ReviewKeys.audit_month_key(occurred),
      "sk" => ReviewKeys.audit_entry_key(occurred.iso8601, id),
      "entity_type" => "AUDIT_LOG_ENTRY",
      "id" => id,
      "action" => action,
      "response_id" => response_id,
      "actor_id" => actor_id,
      "target_viewer_id" => target_viewer_id,
      "metadata" => metadata,
      "occurred_at" => occurred.iso8601,
      "gsi6pk" => "TARGET##{ReviewKeys.share_request_key(response_id)}",
      "gsi6sk" => "AUDIT##{occurred.iso8601}"
    }.compact
  end
end
