#!/usr/bin/ruby

require_relative 'ModTools'
require_relative 'ScanTransfers'

THIS_FILE = File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__

@@pl = PlayerList.new(File.expand_path("../players", THIS_FILE))
@@wi = Interface.new

filename = "/home/kiwi/62b"
if (File.exist?(filename))
	m = ModTools.load(filename)
else
	m = ModTools.new(filename)
end


begin
	m.update
	message = "[b][color=purple]Round is over. No posting, please. Final update coming shortly.[/color][/b]"

	rooms = m.rooms[m.roundnum]
	for room in rooms
		@@wi.post(room.thread, message)
	end

	scan_transfers(m, @@wi, @@pl, true)

	t_england = rooms[1].get_transfer
	t_ruritania = rooms[0].get_transfer

	message = "[b][color=purple]Like all good things, this game has come to an end."
	message << "\n\nThe final transfers happened as follows:"
	if t_england
		message << "\n#{@@pl[rooms[1].leader].name} is the leader of England and decided to send #{@@pl[t_england].name} to Ruritania."
	else
		t_england = rooms[1].players.shuffle[0]
		message << "\n#{@@pl[rooms[1].leader].name} is the leader of England, but did not give any transfer orders, so #{@@pl[t_england].name} was randomly selected to be sent to Ruritania."
	end
	if t_ruritania
		message << "\n#{@@pl[rooms[0].leader].name} is the leader of Ruritania and decided to send #{@@pl[t_ruritania].name} to England."
	else
		t_england = rooms[1].players.shuffle[0]
		message << "\n#{@@pl[rooms[0].leader].name} is the leader of Ruritania, but did not give any transfer orders, so #{@@pl[t_ruritania].name} was randomly selected to be sent to England."
	end

	if t_england == 8 #rathstar sent
		message << "\n\nOur illustrious President mowglee decided it would be best to remain in England, and it is good he did for the bomber rathstar travelled abroad to Ruritania whereupon he promptly exploded, no doubt taking a few ModBots with him.\n\nBLUE TEAM WINS!"
	elsif t_england == 12 #mowglee sent
		message << "\n\nOur illustrious President mowglee decided it would be best to travel abroad, and it is good he did for the bomber rathstar remained in England and shortly after mowglee left, rathstar promptly exploded, no doubt taking a few ModBots with him, but mowglee is safe.\n\nBLUE TEAM WINS!"
	else
		message << "\n\nOur illustrious President mowglee decided it would be best to remain in England, but unfortunately for him the bomber rathstar exploded, and mowglee was no more.\n\nRED TEAM WINS!"
	end

	message << "[/color][/b]"

	message << "\n\nThanks to everyone for playing, and for bearing with me as I tried to fight wih my ModBot and get it to work.\nI'm sorry that the game turned out to be very boring; I think Mach was correct that the reason was because there were no roles that punished card shares. It was my first time modding, and I'll know better for next time.\n\nThanks again to everyone for playing! I'll have a few more comments to make, probably tomorrow, once I get a chance to post."

	puts message
	@@wi.post(1138843, message)
ensure
	@@wi.stop
end
