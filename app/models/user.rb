class User
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :id, :string
  attribute :conductor_one_id, :string
  attribute :slack_user_id, :string
  attribute :display_name, :string
  attribute :email, :string
  attribute :primary_manager_id, :string
  attribute :created_at, :datetime
  attribute :updated_at, :datetime

  validates :id, :display_name, presence: true

  # slack_user_id is intentionally NOT required: OrgChart::ResyncService can
  # pre-provision a User row (from ConductorOne data, correlated by email)
  # for someone who hasn't signed into Slack yet. SessionsController links
  # that row to a real slack_user_id on their first "Sign in with Slack".

  def self.from_item(item)
    return nil if item.nil?

    new(
      id: item["id"],
      conductor_one_id: item["conductor_one_id"],
      slack_user_id: item["slack_user_id"],
      display_name: item["display_name"],
      email: item["email"],
      primary_manager_id: item["primary_manager_id"],
      created_at: item["created_at"] && Time.iso8601(item["created_at"]),
      updated_at: item["updated_at"] && Time.iso8601(item["updated_at"])
    )
  end

  def to_item
    item = {
      "pk" => ReviewKeys.user_key(id),
      "sk" => ReviewKeys.user_key(id),
      "entity_type" => "USER",
      "id" => id,
      "conductor_one_id" => conductor_one_id,
      "slack_user_id" => slack_user_id,
      "display_name" => display_name,
      "email" => email,
      "primary_manager_id" => primary_manager_id,
      "created_at" => (created_at || Time.current).iso8601,
      "updated_at" => Time.current.iso8601
    }.compact

    # Sparse GSI1: only populated once a real Slack identity exists, so a
    # pre-provisioned (resync-only, not-yet-signed-in) user never collides
    # with another pre-provisioned user under the same empty-string key.
    if slack_user_id.present?
      item["gsi1pk"] = ReviewKeys.slack_key(slack_user_id)
      item["gsi1sk"] = ReviewKeys.user_key(id)
    end

    item
  end

  # Deliberately NOT a stored attribute. Admin status must not be something
  # anyone with plain DynamoDB write access could grant themselves --
  # that would undermine the whole "I am the only one who can control
  # viewing privileges" key-custody model (an infra operator could flip a
  # DB boolean, then use the app's own UI to approve their own share
  # requests). Instead it's derived from an env var only the app's deployer
  # controls (a Union Station secret), checked against Slack identity.
  def admin?
    ADMIN_SLACK_USER_IDS.include?(slack_user_id.to_s)
  end

  ADMIN_SLACK_USER_IDS = ENV.fetch("ADMIN_SLACK_USER_IDS", "").split(",").map(&:strip).to_set.freeze
  private_constant :ADMIN_SLACK_USER_IDS
end
