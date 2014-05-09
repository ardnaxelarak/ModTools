#!/usr/bin/ruby

require_relative "Bot2r1b"
require_relative "Setup"

unless ARGV.length > 0
	puts "Usage: #{File.basename(__FILE__)} <filename>"
	exit
else
	filename = ARGV.shift
end

THIS_FILE = File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__

if (File.exist?(filename))
	b = YAML::load(File.read(filename))
else
	puts "#{filename} does not exist"
	exit
end

begin
	if (b.class == Bot2r1b)
		b.update
		b.auto_next_round("Friday, 14:00", "[b][color=purple]You may not colour reveal or colour share. Only full reveals are allowed.[/color][/b]")
	end
ensure
	close_connections
end
