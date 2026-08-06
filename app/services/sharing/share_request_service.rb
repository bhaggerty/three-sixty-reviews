module Sharing
  # Creates a pending request in the admin's approval queue. Deliberately
  # does NOT unlock any content itself -- per the confirmed key-custody
  # model, the admin is the sole approver of every reveal, so clicking
  # "share" only ever requests access.
  class ShareRequestService
    def initialize(share_request_repository: ShareRequestRepository.new, audit_log_repository: AuditLogRepository.new)
      @share_request_repository = share_request_repository
      @audit_log_repository = audit_log_repository
    end

    def request_share(response_id:, requested_by_id:, target_viewer_id:)
      share_request = ShareRequest.new(
        id: SecureRandom.uuid,
        response_id: response_id,
        requested_by_id: requested_by_id,
        target_viewer_id: target_viewer_id,
        status: "pending"
      )
      share_request_repository.create(share_request)

      audit_log_repository.record(AuditLogEntry.new(
        id: SecureRandom.uuid,
        action: "share_requested",
        response_id: response_id,
        actor_id: requested_by_id,
        target_viewer_id: target_viewer_id
      ))

      share_request
    end

    private

    attr_reader :share_request_repository, :audit_log_repository
  end
end
