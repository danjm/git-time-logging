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

class Timelog
	attr_accessor :branch_times, :tracked_times, :saved_tracked_times, :reflogs, :branch_numbers, :today, :log_days_since
	
	def initialize reflogs, days_back
		@today = Date.today
		@log_days_since = today - days_back
		@branch_times = Hash.new(0)

		sortedReflogs = reflogs.split(/\n+/)
			.select  {|line| line.match(/checkout/) && log_days_since < (line_to_Date line)}
			.sort_by {|line| line_to_DateTime line}

		sortedReflogs.each_with_index do |line, index|
			branch = line.match(/\sto\s(BLNP-\d+)/)
			if branch && index < sortedReflogs.length - 1
				@branch_times[branch[1]] += hour_difference sortedReflogs[index + 1], line
			end
		end
		
		reset_tracked_times
		save_tracked_times
		@reflogs = reflogs
		@branch_numbers = @branch_times.keys.map{|key| key.match(/(\d+)/)[1]}
	end
	
	def add_branch_number branch_number
		@branch_numbers.insert -1, branch_number
	end
	
	def set_time branch_num, hours
		@tracked_times['BLNP-' + branch_num] = hours_to_tracked_time hours
	end
	
	def reset_tracked_times
		@tracked_times = @branch_times.dup.update(@branch_times){|key, hours| hours_to_tracked_time(hours)}
	end
	
	def save_tracked_times
		@saved_tracked_times = @tracked_times.dup
	end
	
	def undo_tracked_times_edits
		@tracked_times = @saved_tracked_times.dup
	end
	
	private
	
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
			
			val > 0 ? "#{val}#{time_unit[0]} " : ""
		end
		
		["weeks", "days", "hours", "minutes"].map{|time_unit| to_time(hours, time_unit)}.join.strip
	end
end

days_back = (ARGV[0] || 8).to_i
reflogs = `git reflog --date=default`

time_log = Timelog.new reflogs, days_back

def get_top_level_input tracked_times=false
	puts "Your time tracked per branch:" if !!tracked_times
	pp tracked_times if !!tracked_times
	puts "What would you like to do?"
	puts "1- commit times, 2- edit times, 3-add branch, 4- exit"
	$stdin.gets.chomp.to_s
end

edit_message = "Enter the issue number you wish to edit. 'x' to cancel edits, 's' to save changes and finish editing:"
add_message = "Enter the issue number you wish to add. 'x' to cancel additions, 's' to save changes and finish adding:"

input = get_top_level_input time_log.tracked_times
while !['1', '4', 'x'].include? input
	if input != '2' && input != '3'
		input = get_top_level_input
	else
		puts "#{input == '2' ? edit_message : add_message}"
		branch_to_edit = $stdin.gets.chomp.to_s
		if ['x', 's'].include? branch_to_edit
			time_log.undo_tracked_times_edits if branch_to_edit == 'x'
			time_log.save_tracked_times if branch_to_edit == 's'
			input = get_top_level_input time_log.tracked_times
		#TODO check that branch number is actually a branch when adding (input == '3')
		#TODO add only for adding branch?
		#TODO delete
		#TODO clean this whole thing up somehow
		#TODO prevent adding existing branches
		elsif input == '2' && time_log.branch_numbers.include?(branch_to_edit) || input == '3'
			time_log.add_branch_number(branch_to_edit) if input == '3'
			puts "Enter the hours you'd like to track for BLNP-#{branch_to_edit}. ('x' to cancel)"
			new_tracked_hours = $stdin.gets.chomp.to_s
			if new_tracked_hours.to_f <= 0 && new_tracked_hours != '0'
				puts "Invalid hours entered"
			else
				time_log.set_time branch_to_edit, new_tracked_hours.to_f
				puts "Branch times edited. Time tracked is now:"
				pp time_log.tracked_times
			end
		else
			puts "You have not worked on #{branch_to_edit} in the past #{days_back} days."
		end
	end
end
if input == '1'
	# time_log_filename = time_log.today.to_s + '_time_logs.txt'

	# File.open(time_log_filename, 'w') do |f|
	# 	f.puts "#{time_log.log_days_since} - #{time_log.today}"
	# 	PP.pp(time_log.tracked_times, f)
	# end

	# exec 'subl ' + time_log_filename
	commits = time_log
		.tracked_times
		.select{|name, tracked_time| tracked_time.length > 0}
		.map do |branch_time|
			'git commit --allow-empty -m "' +
			"#{branch_time[0]} #time #{branch_time[1]} Time logged on #{time_log.today.to_s}" +
			'"'
		end
	exec commits.join(" && ")
end
