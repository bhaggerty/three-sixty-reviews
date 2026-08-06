module Slack
  class WebApiClient
    BASE_URL = "https://slack.com/api"

    def initialize(http: Faraday.new(url: BASE_URL), bot_token: ENV["SLACK_BOT_TOKEN"])
      @http = http
      @bot_token = bot_token
    end

    def views_open(trigger_id:, view:)
      post("/views.open", trigger_id: trigger_id, view: view)
    end

    def views_push(trigger_id:, view:)
      post("/views.push", trigger_id: trigger_id, view: view)
    end

    # `channel:` can be a user id -- Slack opens/uses that user's DM channel.
    def chat_post_message(channel:, text:)
      post("/chat.postMessage", channel: channel, text: text)
    end

    private

    attr_reader :http, :bot_token

    def post(path, body)
      response = http.post(path) do |req|
        req.headers["Authorization"] = "Bearer #{bot_token}"
        req.headers["Content-Type"] = "application/json; charset=utf-8"
        req.body = body.to_json
      end
      JSON.parse(response.body)
    end
  end
end
