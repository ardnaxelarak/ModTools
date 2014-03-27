#!/usr/bin/ruby

require 'crypt/rot13'
include Crypt
require_relative 'PlayerList'
require_relative 'WebInterface'

unless ARGV.length >= 2
	puts "Usage: #{File.basename(__FILE__)} threadID player1 [player2 ...]"
	exit
else
	tid = ARGV.shift
end

THIS_FILE = File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__

@@pl = PlayerList.new(File.expand_path("../players", THIS_FILE))
@@wi = Interface.new("personal_auth")

puts "Warning: you are not logged in" unless @@wi.logged_in

list = []
while ARGV.length > 0
	next unless id = @@pl.get_player(ARGV.shift)
	list.push(@@pl[id].name)
end

puts "Enter your message to the following users: #{list.join(", ")}"
text = ""
while (line = gets)
	text << line
end
text.chomp!
exit if text == ""

@@wi.post(tid, "[b]whisper #{list.join(", ")}[/b]\n[o]#{Rot13.new(text)}[/o]")
@@wi.send_geekmail(list.join(","), "Whisper", text)

@@wi.stop
