#!/usr/bin/ruby

require_relative 'Bot2r1b'
require_relative 'Scan'
require_relative 'Setup'
require 'yaml'

$wi.verbose = false

puts Time.now.strftime("%d/%m/%Y %H:%M")

THIS_FILE = File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__
END_LINE = "--------------------"

actname = File.expand_path("../active_games", THIS_FILE)
unless File.exist?(actname)
	puts "active_games not found"
	puts END_LINE
	exit
end
list = File.read(actname).split("\n").uniq
if list.length == 0
	puts "no active games"
	puts END_LINE
	exit
end

begin
	check_mail(true)
	for filename in list
		puts "Opening #{filename}"
		if (File.exist?(filename))
			b = YAML::load(File.read(filename))
		else
			next
		end

		if (b.class == Bot2r1b)
			b.update
			b.scan(true)
			b.tally(false, nil, false)
			# scan_transfers(b, true)
			b.save
		end
	end
ensure
	close_connections
	puts END_LINE
end
