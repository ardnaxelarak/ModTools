#!/usr/bin/ruby

require_relative 'Bot2r1b'

unless ARGV.length > 0
	puts "Usage: #{File.basename(__FILE__)} <filename>"
	exit
else
	filename = ARGV.shift
end

THIS_FILE = File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__

@@pl = PlayerList.new(File.expand_path("../players", THIS_FILE))
@@wi = Interface.new(File.expand_path("../default_auth", THIS_FILE))

if (File.exist?(filename))
	b = YAML::load(File.read(filename))
else
	puts "#{filename} does not exist"
	exit
end

begin
	if (b.class == Bot2r1b)
		b.update
		for room in b.rooms[b.roundnum]
			@@wi.post(room.thread, "[b][color=purple]Round is over. Please stop posting.[/color][/b]")
		end
	end
ensure
	@@wi.stop
end
