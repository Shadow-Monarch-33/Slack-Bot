require "dotenv/load"
require "time"

loop do
  puts "What time should the reminders start? (HH:MM)"

  start_time_input = gets.chomp

  if !start_time_input.match?(/^\d{2}:\d{2}$/)
    puts "Please enter the time in HH:MM format."
    next
  end

  begin
    start_time = Time.strptime(start_time_input, "%H:%M")
    break
  rescue ArgumentError
    puts "Please enter a valid time in HH:MM format."
  end
end

loop do
  puts "What time should the reminders start? (HH:MM)"

  end_time_input = gets.chomp

  if !end_time_input.match?(/^\d{2}:\d{2}$/)
    puts "Please enter the time in HH:MM format."
    next
  end

  begin
    end_time = Time.strptime(end_time_input, "%H:%M")
    break
  rescue ArgumentError
    puts "Please enter a valid time in HH:MM format."
  end
end

if end_time <= start_time
  puts "End time must be after the start time."
  exit
end

loop do
  puts "How often should I remind you? (Minutes)"

  interval_input = gets.chomp.to_f

  if interval_input > 0
    break
  else
    puts "Interval must be greater than 0."
  end
end

puts "What should the reminder message be?"
reminder_message = gets.chomp

require_relative "reminder_worker"

current_reminder_time = start_time

while current_reminder_time <= end_time
  ReminderWorker.perform_at(
    current_reminder_time,
    reminder_message
  )

  current_reminder_time += interval_input * 60
end