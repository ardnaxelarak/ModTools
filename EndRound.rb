#!/usr/bin/ruby

require_relative 'Bot2r1b'

unless ARGV.length > 0
	puts "Usage: modbotendround <filename>"
	exit
else
	filename = ARGV.shift
end

THIS_FILE = File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__

@@pl = PlayerList.new(File.expand_path("../players", THIS_FILE))
@@wi = Interface.new(File.expand_path("../default_auth", THIS_FILE))

unless @@wi.logged_in
	puts "Failed to log in"
	exit
end

if (File.exist?(filename))
	b = Bot2r1b.load(filename)
else
	puts "#{filename} does not exist"
	exit
end

begin
	b.update
	for room in b.rooms[b.roundnum]
		@@wi.post(room.thread, "[b][color=purple]Round is over. Please stop posting.[/color][/b]")
	end
ensure
	@@wi.stop
end
