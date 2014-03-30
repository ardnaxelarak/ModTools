#!/usr/bin/ruby

require_relative 'Bot2r1b'
require 'yaml'

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

@@pl = PlayerList.new(File.expand_path("../players", THIS_FILE))
@@wi = Interface.new(File.expand_path("../default_auth", THIS_FILE))
@@wi.verbose = false

begin
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
			b.save
		end
	end
ensure
	@@wi.stop
	puts END_LINE
end
