# Union Station polls this for liveness (see memory: reference_union_station).
# Deliberately cheap -- confirms the DynamoDB client is configured, not a
# live round-trip, so this endpoint can't be slowed down or exhausted by
# AWS-side issues.
class HealthController < ApplicationController
  skip_before_action :require_login

  def show
    DynamoDbClient.client
    render plain: "ok"
  end
end
