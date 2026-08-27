require "sidekiq"
require "dotenv/load"
require "slack-ruby-client"

class ReminderWorker
  include Sidekiq::Worker

  def perform(message)
    Slack.configure do |config|
      config.token = ENV["SLACK_BOT_TOKEN"]
    end

    client = Slack::Web::Client.new

    client.chat_postMessage(
      channel: ENV["SLACK_CHANNEL_ID"],
      text: message
    )
  end
end