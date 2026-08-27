require "dotenv/load"
require "slack-ruby-client"

Slack.configure do |config|
  config.token = ENV["SLACK_BOT_TOKEN"]
end

client = Slack::Web::Client.new

puts "Bot Connected"