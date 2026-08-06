module OrgChart
  # Manual, admin-triggered resync (no webhook/poller in v1 -- see plan
  # doc). Two passes are required: a report's primary_manager_id must
  # resolve to an internal User#id, but the manager's internal User row may
  # not exist yet the first time we see the report (pagination order isn't
  # guaranteed to put managers before reports). Pass 1 ensures every
  # ConductorOne user has an internal row; pass 2 resolves manager
  # references now that every ConductorOne id maps to one.
  #
  # Loads the existing user set once up front (O(1) scan) rather than doing
  # a lookup-per-ConductorOne-user, which would be an O(n) scan repeated n
  # times for an org of n people.
  class ResyncService
    def initialize(client: OrgChart::Client.new, user_repository: UserRepository.new)
      @client = client
      @user_repository = user_repository
    end

    def resync!
      c1_users = fetch_all_c1_users
      existing_by_conductor_one_id, existing_by_email = index_existing_users

      by_conductor_one_id = c1_users.to_h do |c1_user|
        [ c1_user["id"], upsert_basic(c1_user, existing_by_conductor_one_id, existing_by_email) ]
      end

      c1_users.each { |c1_user| resolve_primary_manager(c1_user, by_conductor_one_id) }

      c1_users.size
    end

    private

    attr_reader :client, :user_repository

    def fetch_all_c1_users
      users = []
      page_token = nil

      loop do
        page = client.list_users(page_token: page_token)
        users.concat(page[:users])
        page_token = page[:next_page_token]
        break if page_token.blank?
      end

      users
    end

    def index_existing_users
      existing = user_repository.all
      by_conductor_one_id = existing.index_by(&:conductor_one_id)
      by_email = existing.each_with_object({}) { |u, h| h[u.email.downcase] = u if u.email.present? }
      [ by_conductor_one_id, by_email ]
    end

    # Existing row is found by conductor_one_id first (the stable id once
    # linked), then by email -- the email fallback is what links a
    # resync-created placeholder, or someone who signed into Slack before
    # ever appearing in a resync, to this ConductorOne record instead of
    # creating a duplicate user.
    def upsert_basic(c1_user, existing_by_conductor_one_id, existing_by_email)
      conductor_one_id = c1_user["id"]
      email = c1_user["email"]

      user = existing_by_conductor_one_id[conductor_one_id] ||
        (email.present? && existing_by_email[email.downcase]) ||
        User.new(id: SecureRandom.uuid)

      user.conductor_one_id = conductor_one_id
      user.email = email || user.email
      user.display_name = c1_user["displayName"].presence || user.display_name || email || conductor_one_id

      user_repository.upsert(user)
    end

    def resolve_primary_manager(c1_user, by_conductor_one_id)
      user = by_conductor_one_id[c1_user["id"]]
      manager_c1_id = Array(c1_user["managerIds"]).first
      new_primary_manager_id = manager_c1_id && by_conductor_one_id[manager_c1_id]&.id

      return if user.primary_manager_id == new_primary_manager_id

      user.primary_manager_id = new_primary_manager_id
      user_repository.upsert(user)
    end
  end
end
