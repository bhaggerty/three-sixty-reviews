class ReviewAssignment
  include ActiveModel::Model
  include ActiveModel::Attributes

  DIRECTIONS = %w[up down].freeze
  STATUSES = %w[pending submitted voided].freeze

  attribute :id, :string
  attribute :cycle_id, :string
  attribute :reviewer_id, :string
  attribute :subject_id, :string
  attribute :direction, :string
  attribute :status, :string, default: "pending"
  attribute :snapshot_taken_at, :datetime
  attribute :created_at, :datetime
  attribute :updated_at, :datetime

  validates :id, :cycle_id, :reviewer_id, :subject_id, presence: true
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :status, inclusion: { in: STATUSES }

  def self.from_item(item)
    return nil if item.nil?

    new(
      id: item["id"],
      cycle_id: item["cycle_id"],
      reviewer_id: item["reviewer_id"],
      subject_id: item["subject_id"],
      direction: item["direction"],
      status: item["status"],
      snapshot_taken_at: item["snapshot_taken_at"] && Time.iso8601(item["snapshot_taken_at"]),
      created_at: item["created_at"] && Time.iso8601(item["created_at"]),
      updated_at: item["updated_at"] && Time.iso8601(item["updated_at"])
    )
  end

  # NOTE on GSI2/GSI4: a single DynamoDB item can only carry one value per
  # GSI partition key attribute, so one assignment cannot be indexed under
  # both "reviewer" and "subject" partition keys within the *same* GSI. The
  # approved plan's "GSI2 ByUserRole" describes both access patterns as one
  # index, which isn't representable as a single GSI attribute pair. This
  # splits it into two GSIs that together deliver both named access
  # patterns from the plan:
  #   GSI2 -> "reviews I need to write" (keyed by reviewer_id)
  #   GSI4 -> "reviews about me"        (keyed by subject_id)
  def to_item
    {
      "pk" => ReviewKeys.cycle_key(cycle_id),
      "sk" => ReviewKeys.assignment_key(id),
      "entity_type" => "REVIEW_ASSIGNMENT",
      "id" => id,
      "cycle_id" => cycle_id,
      "reviewer_id" => reviewer_id,
      "subject_id" => subject_id,
      "direction" => direction,
      "status" => status,
      "snapshot_taken_at" => (snapshot_taken_at || Time.current).iso8601,
      "created_at" => (created_at || Time.current).iso8601,
      "updated_at" => Time.current.iso8601,
      "gsi2pk" => ReviewKeys.user_key(reviewer_id),
      "gsi2sk" => ReviewKeys.role_status_cycle(role: "REVIEWER", status: status, cycle_id: cycle_id, assignment_id: id),
      "gsi4pk" => ReviewKeys.user_key(subject_id),
      "gsi4sk" => ReviewKeys.role_status_cycle(role: "SUBJECT", status: status, cycle_id: cycle_id, assignment_id: id)
    }.compact
  end

  def upward? = direction == "up"
  def pending? = status == "pending"
end
