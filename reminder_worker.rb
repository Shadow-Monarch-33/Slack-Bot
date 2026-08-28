require "sidekiq"
require "dotenv/load"
require "slack-ruby-client"

class ReminderWorker
  include Sidekiq::Worker

  def perform(channel, message)
    Slack.configure do |config|
      config.token = ENV["SLACK_BOT_TOKEN"]
    end

    client = Slack::Web::Client.new

    client.chat_postMessage(
      channel: channel,
      text: message
    )
  end
end