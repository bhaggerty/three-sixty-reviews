class ReviewResponse
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :id, :string
  attribute :assignment_id, :string
  attribute :answers_envelope
  attribute :attestation_envelope
  attribute :question_set_version, :string
  attribute :finalized, :boolean, default: false
  attribute :created_at, :datetime
  attribute :updated_at, :datetime

  validates :id, :assignment_id, :answers_envelope, :attestation_envelope, :question_set_version, presence: true

  def self.from_item(item)
    return nil if item.nil?

    new(
      id: item["id"],
      assignment_id: item["assignment_id"],
      answers_envelope: item["answers_envelope"],
      attestation_envelope: item["attestation_envelope"],
      question_set_version: item["question_set_version"],
      finalized: item["finalized"] || false,
      created_at: item["created_at"] && Time.iso8601(item["created_at"]),
      updated_at: item["updated_at"] && Time.iso8601(item["updated_at"])
    )
  end

  def to_item
    {
      "pk" => ReviewKeys.assignment_key(assignment_id),
      "sk" => ReviewKeys.response_key(id),
      "entity_type" => "REVIEW_RESPONSE",
      "id" => id,
      "assignment_id" => assignment_id,
      "answers_envelope" => answers_envelope,
      "attestation_envelope" => attestation_envelope,
      "question_set_version" => question_set_version,
      "finalized" => finalized,
      "created_at" => (created_at || Time.current).iso8601,
      "updated_at" => Time.current.iso8601
    }.compact
  end

  def finalized? = !!finalized
end
