# Centralizes the single-table PK/SK/GSI key-building so the prefix scheme
# (see plan doc: DynamoDB single table design) stays consistent across every
# repository that touches a shared entity type (e.g. both
# ReviewAssignmentRepository and ReviewResponseRepository build "ASSIGNMENT#"
# keys and must agree on the exact format).
module ReviewKeys
  GSI1_SLACK_LOOKUP     = "GSI1".freeze
  GSI2_BY_USER_ROLE     = "GSI2".freeze
  GSI3_ADMIN_SHARE_QUEUE = "GSI3".freeze

  module_function

  def user_key(id) = "USER##{id}"
  def cycle_key(id) = "CYCLE##{id}"
  def assignment_key(id) = "ASSIGNMENT##{id}"
  def response_key(id) = "RESPONSE##{id}"
  def share_request_key(id) = "SHAREREQUEST##{id}"
  def grant_key(scope, viewer_id) = "GRANT##{scope}##{viewer_id}"
  def slack_key(slack_id) = "SLACKID##{slack_id}"
  def audit_month_key(time) = "AUDIT##{time.strftime('%Y-%m')}"
  def audit_entry_key(iso_ts, uuid) = "AUDIT##{iso_ts}##{uuid}"

  def role_status_cycle(role:, status:, cycle_id:, assignment_id:)
    "ROLE##{role}#STATUS##{status}#CYCLE##{cycle_id}##{assignment_id}"
  end

  def role_prefix(role:)
    "ROLE##{role}#"
  end
end
