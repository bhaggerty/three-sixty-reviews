# "Sign in with Slack" (OIDC) is the sole identity system for both web login
# and Slack slash-command/modal submissions -- see plan doc. Discovery mode
# fetches Slack's actual endpoints from its OIDC discovery document rather
# than hardcoding them.
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :openid_connect, {
    name: :slack,
    scope: [ :openid, :email, :profile ],
    response_type: :code,
    issuer: "https://slack.com",
    discovery: true,
    client_options: {
      identifier: ENV["SLACK_CLIENT_ID"],
      secret: ENV["SLACK_CLIENT_SECRET"],
      redirect_uri: "#{ENV.fetch('APP_BASE_URL', 'http://localhost:3000')}/auth/slack/callback"
    }
  }
end

OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.silence_get_warning = true
