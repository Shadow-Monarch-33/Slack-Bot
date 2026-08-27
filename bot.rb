require "dotenv/load"
require "slack-ruby-client"
require "time"

puts "What time shoulder the reminders start? (HH:MM)"
start_time_input = gets.chomp

puts "What time should the reminders end? (HH:MM)"
end_time_input = gets.chomp

puts "How often should I remind you? (Minutes)"
interval_input = gets.chomp.to_i

puts "What should the reminder message be?"
reminder_message = gets.chomp

start_time = Time.parse(start_time_input)
end_time = Time.parse(end_time_input)

current_remainder_time = start_time

while current_remainder_time <= end_time
  puts current_remainder_time.strftime("%H:%M")

  current_remainder_time += interval_input * 60
end

Slack.configure do |config|
  config.token = ENV["SLACK_BOT_TOKEN"]
end

client = Slack::Web::Client.new

auth = client.auth_test

puts "Connected as #{auth.user}"

client.chat_postMessage(
  channel: ENV["SLACK_CHANNEL_ID"],
  text: reminder_message
)