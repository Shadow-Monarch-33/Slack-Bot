require "sinatra"
require "json"
require "dotenv/load"
require "slack-ruby-client"
require "sidekiq/api"

Slack.configure do |config|
  config.token = ENV["SLACK_BOT_TOKEN"]
end

client = Slack::Web::Client.new

conversations = {}
processed_events = {}
user_jobs = {}

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

      if message.downcase == "stop"

        conversations.delete(user)

        client.chat_postMessage(
          channel: channel,
          text: "Stopped all currently set reminders"
        )

        puts "USER JOBS:"
        puts user_jobs[user].inspect

        scheduled_jobs = Sidekiq::ScheduledSet.new

        puts "SCHEDULED JOBS:"
        scheduled_jobs.each do |scheduled_job|
          puts scheduled_job.jid
        end

        user_jobs[user]&.each do |job_id|

          puts "TRYING TO DELETE: #{job_id}"

          job = scheduled_jobs.find do |schedules_job|
            schedules_job.jid == job_id
          end

          puts "FOUND: #{job.inspect}"

          job.delete if job

        end

        user_jobs.delete(user)

        return "OK"
      end

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

        current_time = Time.now.strftime("%H:%M")

        if start_time_input < current_time
          start_time += 24 * 60 * 60
          end_time += 24 * 60 * 60
        end

        require_relative "reminder_worker"

        user_jobs[user] ||= []

        current_reminder_time = start_time + 10

        while current_reminder_time <= end_time

          puts "SCHEDULING: #{current_reminder_time.strftime("%H:%M:%S")}"

          job_id = ReminderWorker.perform_at(
            current_reminder_time,
            channel,
            message_input
          )

          user_jobs[user] << job_id

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