class Grant
  include ActiveModel::Model
  include ActiveModel::Attributes

  SCOPES = %w[CONTENT ATTESTATION].freeze

  attribute :id, :string
  attribute :response_id, :string
  attribute :scope, :string
  attribute :viewer_id, :string
  attribute :granted_by_id, :string
  attribute :share_request_id, :string
  attribute :granted_at, :datetime
  attribute :revoked_at, :datetime
  attribute :created_at, :datetime
  attribute :updated_at, :datetime

  validates :id, :response_id, :viewer_id, :granted_by_id, presence: true
  validates :scope, inclusion: { in: SCOPES }

  def self.from_item(item)
    return nil if item.nil?

    new(
      id: item["id"],
      response_id: item["response_id"],
      scope: item["scope"],
      viewer_id: item["viewer_id"],
      granted_by_id: item["granted_by_id"],
      share_request_id: item["share_request_id"],
      granted_at: item["granted_at"] && Time.iso8601(item["granted_at"]),
      revoked_at: item["revoked_at"] && Time.iso8601(item["revoked_at"]),
      created_at: item["created_at"] && Time.iso8601(item["created_at"]),
      updated_at: item["updated_at"] && Time.iso8601(item["updated_at"])
    )
  end

  def to_item
    {
      "pk" => ReviewKeys.share_request_key(response_id),
      "sk" => ReviewKeys.grant_key(scope, viewer_id),
      "entity_type" => "GRANT",
      "id" => id,
      "response_id" => response_id,
      "scope" => scope,
      "viewer_id" => viewer_id,
      "granted_by_id" => granted_by_id,
      "share_request_id" => share_request_id,
      "granted_at" => (granted_at || Time.current).iso8601,
      "revoked_at" => revoked_at&.iso8601,
      "created_at" => (created_at || Time.current).iso8601,
      "updated_at" => Time.current.iso8601,
      "gsi5pk" => "#{ReviewKeys.user_key(viewer_id)}#GRANTS",
      "gsi5sk" => "#{ReviewKeys.share_request_key(response_id)}##{scope}"
    }.compact
  end

  def active? = revoked_at.nil?
end
