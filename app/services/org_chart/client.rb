module OrgChart
  # Calls ConductorOne's own public API (dogfooding) to read manager/report
  # data. No Ruby SDK exists for it, so this is a direct REST client via
  # Faraday. OAuth2 client-credentials, ~600s token TTL -- token is cached
  # and refreshed with a buffer before expiry.
  class Client
    class ApiError < StandardError; end

    DEFAULT_BASE_URL = "https://api.conductor.one"
    MAX_RETRIES = 3
    TOKEN_EXPIRY_BUFFER = 30 # seconds

    def initialize(
      http: Faraday.new(url: ENV.fetch("CONDUCTORONE_API_BASE_URL", DEFAULT_BASE_URL)),
      client_id: ENV["CONDUCTORONE_CLIENT_ID"],
      client_secret: ENV["CONDUCTORONE_CLIENT_SECRET"],
      sleeper: ->(seconds) { sleep(seconds) }
    )
      @http = http
      @client_id = client_id
      @client_secret = client_secret
      @sleeper = sleeper
      @token = nil
      @token_expires_at = nil
    end

    # Returns { users: [...], next_page_token: String or nil }. Each user
    # hash has at least "id", "email", "displayName", "managerIds".
    def list_users(page_token: nil)
      params = { page_size: 100 }
      params[:page_token] = page_token if page_token.present?

      body = get("/api/v1/users", params)
      {
        users: body["users"] || [],
        next_page_token: body["nextPageToken"]
      }
    end

    private

    attr_reader :http, :client_id, :client_secret, :sleeper

    def get(path, params)
      with_retries do
        response = http.get(path, params) { |req| req.headers["Authorization"] = "Bearer #{access_token}" }
        raise ApiError, "ConductorOne API returned #{response.status}" unless response.success?
        JSON.parse(response.body)
      end
    end

    def with_retries
      attempt = 0
      begin
        yield
      rescue ApiError, Faraday::Error => e
        attempt += 1
        raise if attempt >= MAX_RETRIES
        sleeper.call(backoff_seconds(attempt))
        retry
      end
    end

    def backoff_seconds(attempt)
      [ 0.5 * (2**attempt), 30 ].min
    end

    def access_token
      return @token if @token && @token_expires_at && @token_expires_at > Time.current + TOKEN_EXPIRY_BUFFER

      response = http.post("/oauth2/token") do |req|
        req.headers["Content-Type"] = "application/x-www-form-urlencoded"
        req.body = URI.encode_www_form(
          grant_type: "client_credentials",
          client_id: client_id,
          client_secret: client_secret
        )
      end
      raise ApiError, "ConductorOne token request returned #{response.status}" unless response.success?

      body = JSON.parse(response.body)
      @token = body.fetch("access_token")
      @token_expires_at = Time.current + body.fetch("expires_in", 600)
      @token
    end
  end
end
