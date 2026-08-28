require "sinatra"
require "json"
require "dotenv/load"
require "slack-ruby-client"

Slack.configure do |config|
  config.token = ENV["SLACK_BOT_TOKEN"]
end

client = Slack::Web::Client.new

conversations = {}
processed_events = {}

get "/" do
  "Slack bot is alive"
end

post "/" do
  payload = JSON.parse(request.body.read)

  puts "EVENT ID: #{payload["event_id"]}"
  puts "MESSAGE: #{payload.dig("event", "text")}"

  if payload["type"] == "url_verification"
    content_type :json

    {
      challenge: payload["challenge"]
    }.to_json

  elsif payload["type"] == "event_callback"

    if processed_events[payload["event_id"]]
      puts "DUPLICATE IGNORED"
      return "OK"
    end

    processed_events[payload["event_id"]] = true
    puts "NEW EVENT"

    event = payload["event"]

    if event["bot_id"]
      "OK"

    else
      user = event["user"]
      message = event["text"]
      channel = event["channel"]

      if conversations[user].nil?

        conversations[user] = {
          step: "start_time"
        }

        client.chat_postMessage(
          channel: channel,
          text: "What time should the reminders start? (HH:MM)"
        )

      elsif conversations[user][:step] == "start_time"

        if !message.match?(/^\d{2}:\d{2}$/)

          client.chat_postMessage(
            channel: channel,
            text: "Please enter the time in HH:MM format."
          )

        else

          begin
            Time.strptime(message, "%H:%M")

            conversations[user][:start_time] = message
            conversations[user][:step] = "end_time"

            client.chat_postMessage(
              channel: channel,
              text: "What time should the reminders end? (HH:MM)"
            )

          rescue ArgumentError

            client.chat_postMessage(
              channel: channel,
              text: "Please enter a valid time."
            )

          end
        end

      elsif conversations[user][:step] == "end_time"

        if !message.match?(/^\d{2}:\d{2}$/)

          client.chat_postMessage(
            channel: channel,
            text: "Please enter the time in HH:MM format."
          )

        else

          begin
            Time.strptime(message, "%H:%M")

            conversations[user][:end_time] = message
            conversations[user][:step] = "interval"

            client.chat_postMessage(
              channel: channel,
              text: "How often should I remind you? (Minutes)"
            )

          rescue ArgumentError

            client.chat_postMessage(
              channel: channel,
              text: "Please enter a valid time."
            )

          end
        end

      elsif conversations[user][:step] == "interval"

        interval = message.to_f

        if interval > 0

          conversations[user][:interval] = interval
          conversations[user][:step] = "message"

          client.chat_postMessage(
            channel: channel,
            text: "What should the reminder message be?"
          )

        else

          client.chat_postMessage(
            channel: channel,
            text: "Interval must be greater than 0."
          )

        end

      elsif conversations[user][:step] == "message"

        conversations[user][:message] = message

        start_time_input = conversations[user][:start_time]
        end_time_input = conversations[user][:end_time]
        interval_time = conversations[user][:interval]
        message_input = conversations[user][:message]

        start_time = Time.strptime(start_time_input, "%H:%M")
        end_time = Time.strptime(end_time_input, "%H:%M")

        if end_time <= start_time
          end_time += 24 * 60 * 60
        end

        current_reminder_time = start_time + 10

        require_relative "reminder_worker"

        while current_reminder_time <= end_time

          ReminderWorker.perform_at(
            current_reminder_time,
            channel,
            message_input
          )

          current_reminder_time += interval_time * 60
        end

        puts conversations[user].inspect

        client.chat_postMessage(
          channel: channel,
          text: "🎉Reminder created!🎉"
        )

        conversations.delete(user)

      end

      "OK"
    end

  else
    "OK"
  end
end