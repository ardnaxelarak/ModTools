#!/usr/bin/ruby

require_relative 'ModTools'

THIS_FILE = File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__

$pl = PlayerList.new(File.expand_path("../players", THIS_FILE))
$wi = Interface.new

filename = "/home/kiwi/62b"
if (File.exist?(filename))
	m = ModTools.load(filename)
else
	m = ModTools.new(filename)
end


begin
	m.update

	rooms = m.rooms[m.roundnum]
	for room in rooms
		message = "[color=#009900]The round will end in TWO HOURS. Please, due to the presence of Con-Artists, be sure to submit transfer orders (to me, modkiwi) if you have [b][i]any[/i][/b] votes. For those of you who are lazy, here are quick links to send in your transfer orders:"
		for player in room.players.collect{|pid| $pl[pid]}.sort_by{|player| player.name.upcase}
			message << "\n[url=http://boardgamegeek.com/geekmail/compose?touser=modkiwi&subject=62b%20Transfer%20Orders&body=%5Bb%5Dtransfer%20#{player.name}%5B/b%5D]Send #{player.name}[/url]"
		end

		message << "[/color]"

		# puts message
		$wi.post(room.thread, message)
	end
ensure
	$wi.stop
end
