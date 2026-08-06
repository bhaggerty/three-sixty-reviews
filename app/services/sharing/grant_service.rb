module Sharing
  # Admin-only approve/deny for a pending ShareRequest. Approving creates a
  # CONTENT grant for the target viewer -- content only, never attestation.
  # Attestation decryption is gated purely by the viewer being the admin
  # (checked in ReviewResponsePolicy), not by any Grant record; there is
  # deliberately no path in this service that grants ATTESTATION scope.
  class GrantService
    class NotAdmin < StandardError; end
    class AlreadyDecided < StandardError; end

    def initialize(
      grant_repository: GrantRepository.new,
      share_request_repository: ShareRequestRepository.new,
      audit_log_repository: AuditLogRepository.new
    )
      @grant_repository = grant_repository
      @share_request_repository = share_request_repository
      @audit_log_repository = audit_log_repository
    end

    def approve(share_request:, admin:)
      raise NotAdmin unless admin.admin?
      raise AlreadyDecided unless share_request.pending?

      decide(share_request, admin, "approved")

      grant = grant_repository.create(Grant.new(
        id: SecureRandom.uuid,
        response_id: share_request.response_id,
        scope: "CONTENT",
        viewer_id: share_request.target_viewer_id,
        granted_by_id: admin.id,
        share_request_id: share_request.id
      ))

      record_audit("share_approved", response_id: share_request.response_id, admin: admin, target_viewer_id: share_request.target_viewer_id)
      record_audit("grant_created", response_id: share_request.response_id, admin: admin, target_viewer_id: share_request.target_viewer_id)

      grant
    end

    def deny(share_request:, admin:)
      raise NotAdmin unless admin.admin?
      raise AlreadyDecided unless share_request.pending?

      decide(share_request, admin, "denied")
      record_audit("share_denied", response_id: share_request.response_id, admin: admin, target_viewer_id: share_request.target_viewer_id)

      share_request
    end

    # Direct admin revocation, independent of the share-request flow (e.g.
    # the admin changes their mind after already approving a share).
    def revoke(grant:, admin:)
      raise NotAdmin unless admin.admin?

      grant.revoked_at = Time.current
      grant_repository.save(grant)
      record_audit("grant_revoked", response_id: grant.response_id, admin: admin, target_viewer_id: grant.viewer_id)

      grant
    end

    private

    attr_reader :grant_repository, :share_request_repository, :audit_log_repository

    def decide(share_request, admin, status)
      share_request.status = status
      share_request.decided_by_id = admin.id
      share_request.decided_at = Time.current
      share_request_repository.save(share_request)
    end

    def record_audit(action, response_id:, admin:, target_viewer_id:)
      audit_log_repository.record(AuditLogEntry.new(
        id: SecureRandom.uuid,
        action: action,
        response_id: response_id,
        actor_id: admin.id,
        target_viewer_id: target_viewer_id
      ))
    end
  end
end
