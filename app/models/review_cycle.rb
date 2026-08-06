class ReviewCycle
  include ActiveModel::Model
  include ActiveModel::Attributes

  STATUSES = %w[draft active closed].freeze

  attribute :id, :string
  attribute :name, :string
  attribute :status, :string, default: "draft"
  attribute :question_set_version, :string
  attribute :org_chart_snapshot_at, :datetime
  attribute :created_at, :datetime
  attribute :updated_at, :datetime

  validates :id, :name, :question_set_version, presence: true
  validates :status, inclusion: { in: STATUSES }

  def self.from_item(item)
    return nil if item.nil?

    new(
      id: item["id"],
      name: item["name"],
      status: item["status"],
      question_set_version: item["question_set_version"],
      org_chart_snapshot_at: item["org_chart_snapshot_at"] && Time.iso8601(item["org_chart_snapshot_at"]),
      created_at: item["created_at"] && Time.iso8601(item["created_at"]),
      updated_at: item["updated_at"] && Time.iso8601(item["updated_at"])
    )
  end

  def to_item
    {
      "pk" => ReviewKeys.cycle_key(id),
      "sk" => ReviewKeys.cycle_key(id),
      "entity_type" => "REVIEW_CYCLE",
      "id" => id,
      "name" => name,
      "status" => status,
      "question_set_version" => question_set_version,
      "org_chart_snapshot_at" => org_chart_snapshot_at&.iso8601,
      "created_at" => (created_at || Time.current).iso8601,
      "updated_at" => Time.current.iso8601
    }.compact
  end

  def active? = status == "active"
end
