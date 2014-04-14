#!/usr/bin/ruby

require 'crypt/rot13'
include Crypt
require_relative 'PlayerList'
require_relative 'WebInterface'
require_relative 'Bot2r1b'

def get_room(uid, list)
	for filename in list
		if (File.exist?(filename))
			b = YAML::load(File.read(filename))
			next unless b.class == Bot2r1b
		else
			next
		end

		for room in b.rooms[b.roundnum]
			return room if room.players.include?(uid)
		end
	end
	return nil
end

unless ARGV.length >= 1
	puts "Usage: #{File.basename(__FILE__)} player1 [player2 ...]"
	exit
end

THIS_FILE = File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__

actname = File.expand_path("../active_games", THIS_FILE)
@@pl = PlayerList.new(File.expand_path("../players", THIS_FILE))
@@wi = Interface.new("personal_auth")

pieces = File.read("personal_auth").split("\n")
user = pieces[0]
uid = @@pl.get_player(user)

list = File.read(actname).split("\n").uniq

room = get_room(uid, list)

unless room
	puts "Cannot find room"
	exit
end

list = []
while ARGV.length > 0
	next unless id = @@pl.get_player(ARGV.shift, room.players)
	list.push(@@pl[id].name)
end

puts "Enter your message to the following users: #{list.join(", ")}"
text = ""
while (line = gets)
	text << line
end
text.chomp!
exit if text == ""

@@wi.post(room.thread, "[b]whisper #{list.join(", ")}[/b]\n[o]#{Rot13.new(text)}[/o]")
@@wi.send_geekmail(list.join(","), "Whisper", text)

@@wi.stop
