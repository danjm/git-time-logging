=begin
	- see list of times per branch since last push to time tracking branch
	- add, subtract, delete set each time
	- crud message for any time
	- submit each time
	- submit all times
	- store reflog in commit
	
	- an object with private variables
		- object: keys- issue number, value- checkout, check in messages
		- object: keys- issue number, value- total time in time tracking format
		- object: keys- all reflogs being counted
=end

require 'date'
require 'pp'

days_back = (ARGV[0] || 8).to_i

def line_to_ class_, line
	class_.parse(line.match(/\{(.+)\}/)[1].to_s)
end

def line_to_Date line
	line_to_ Date, line
end

def line_to_DateTime line
	line_to_ DateTime, line
end

def hour_difference end_time, start_time
	[end_time, start_time].map {|l| line_to_DateTime l}.reduce(:-).to_f * 24
end

def create_urls branch_keys
	branch_keys.map{|branch_name| ' ' + Base_url + branch_name.match(/BLNP\-\d+/).to_s}.join
end

def hours_to_tracked_time hours
	def to_time val, time_unit
		val = case time_unit
			when "weeks" then val.to_i / 40
			when "days" then val.to_i % 40 / 8
			when "hours" then val.to_i % 8
			when "minutes" then (val % 1 * 60).to_i
		end
		
		val > 0 ? "#{val} #{time_unit} " : ""
	end
	
	["weeks", "days", "hours", "minutes"].map{|time_unit| to_time(hours, time_unit)}.join.strip
end

reflogs = `git reflog --date=default`
today = Date.today
log_days_since = today - days_back
branch_times = Hash.new(0)

sortedReflogs = reflogs.split(/\n+/)
	.select  {|line| line.match(/checkout/) && log_days_since < (line_to_Date line)}
	.sort_by {|line| line_to_DateTime line}

sortedReflogs.each_with_index do |line, index|
	branch = line.match(/\sto\s(BLNP-\d+)/)
	if branch && index < sortedReflogs.length - 1
		branch_times[branch[1]] += hour_difference sortedReflogs[index + 1], line
	end
end

tracked_times = branch_times.dup.update(branch_times){|key, hours| hours_to_tracked_time(hours)}
branch_numbers = branch_times.keys.map{|key| key.match(/(\d+)/)[1]}

def get_top_level_input
	puts "What would you like to do?"
	puts "1- commit times to JIRA, 2- edit times, 3- exit"
	$stdin.gets.chomp.to_s
end

puts "Your time tracked per branch:"
pp tracked_times
input = get_top_level_input
while !['1', '3'].include? input
	if input != '2'
		input = get_top_level_input
	else
		puts "Enter the issue number you wish to edit. 'x' to cancel edits, 's' to save change and finish editing:"
		branch_to_edit = $stdin.gets.chomp.to_s
		if branch_to_edit == 'x'
			input = get_top_level_input
		elsif branch_numbers.include? branch_to_edit
			puts "Enter the hours you'd like to track for BLNP-#{branch_to_edit}. ('x' to cancel_"
			new_tracked_hours = $stdin.gets.chomp.to_s
			if new_tracked_hours.to_f <= 0 && new_tracked_hours != '0'
				puts "Invalid hours entered"
			else
				tracked_times['BLNP-' + branch_to_edit] = hours_to_tracked_time new_tracked_hours.to_f
				puts "Branch times edited. Time tracked is now:"
				pp tracked_times
			end
		else
			puts "You have not worked on #{branch_to_edit} in the past #{days_back} days."
		end
	end
end
if input == '1'
	time_log_filename = today.to_s + '_time_logs.txt'

	File.open(time_log_filename, 'w') do |f|
		f.puts "#{log_days_since} - #{today}"
		PP.pp(tracked_times, f)
	end

	exec 'subl ' + time_log_filename
end
