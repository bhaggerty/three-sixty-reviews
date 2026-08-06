class ShareRequest
  include ActiveModel::Model
  include ActiveModel::Attributes

  STATUSES = %w[pending approved denied].freeze

  attribute :id, :string
  attribute :response_id, :string
  attribute :requested_by_id, :string
  attribute :target_viewer_id, :string
  attribute :status, :string, default: "pending"
  attribute :decided_by_id, :string
  attribute :decided_at, :datetime
  attribute :created_at, :datetime
  attribute :updated_at, :datetime

  validates :id, :response_id, :requested_by_id, :target_viewer_id, presence: true
  validates :status, inclusion: { in: STATUSES }

  def self.from_item(item)
    return nil if item.nil?

    new(
      id: item["id"],
      response_id: item["response_id"],
      requested_by_id: item["requested_by_id"],
      target_viewer_id: item["target_viewer_id"],
      status: item["status"],
      decided_by_id: item["decided_by_id"],
      decided_at: item["decided_at"] && Time.iso8601(item["decided_at"]),
      created_at: item["created_at"] && Time.iso8601(item["created_at"]),
      updated_at: item["updated_at"] && Time.iso8601(item["updated_at"])
    )
  end

  # GSI3 is sparse and deliberately only populated for pending requests, so
  # the admin queue index (Query gsi3pk="SHAREQUEUE#PENDING") never has to
  # filter out decided rows -- decided requests just drop out of it because
  # their gsi3pk/gsi3sk attributes are absent (repository omits them on
  # update, it does not merely set them to nil).
  def to_item
    created = created_at || Time.current
    item = {
      "pk" => ReviewKeys.share_request_key(response_id),
      "sk" => ReviewKeys.share_request_key(id),
      "entity_type" => "SHARE_REQUEST",
      "id" => id,
      "response_id" => response_id,
      "requested_by_id" => requested_by_id,
      "target_viewer_id" => target_viewer_id,
      "status" => status,
      "decided_by_id" => decided_by_id,
      "decided_at" => decided_at&.iso8601,
      "created_at" => created.iso8601,
      "updated_at" => Time.current.iso8601
    }.compact

    if pending?
      item["gsi3pk"] = "SHAREQUEUE#PENDING"
      item["gsi3sk"] = "CREATEDAT##{created.iso8601}##{id}"
    end

    item
  end

  def pending? = status == "pending"
end
