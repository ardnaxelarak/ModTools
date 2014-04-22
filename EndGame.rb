#!/usr/bin/ruby

require_relative 'ModTools'
require_relative 'ScanTransfers'

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
	message = "[b][color=purple]Round is over. No posting, please. Final update coming shortly.[/color][/b]"

	rooms = m.rooms[m.roundnum]
	for room in rooms
		$wi.post(room.thread, message)
	end

	scan_transfers(m, $wi, $pl, true)

	t_england = rooms[1].get_transfer
	t_ruritania = rooms[0].get_transfer

	message = "[b][color=purple]Like all good things, this game has come to an end."
	message << "\n\nThe final transfers happened as follows:"
	if t_england
		message << "\n#{$pl[rooms[1].leader].name} is the leader of England and decided to send #{$pl[t_england].name} to Ruritania."
	else
		t_england = rooms[1].players.shuffle[0]
		message << "\n#{$pl[rooms[1].leader].name} is the leader of England, but did not give any transfer orders, so #{$pl[t_england].name} was randomly selected to be sent to Ruritania."
	end
	if t_ruritania
		message << "\n#{$pl[rooms[0].leader].name} is the leader of Ruritania and decided to send #{$pl[t_ruritania].name} to England."
	else
		t_england = rooms[1].players.shuffle[0]
		message << "\n#{$pl[rooms[0].leader].name} is the leader of Ruritania, but did not give any transfer orders, so #{$pl[t_ruritania].name} was randomly selected to be sent to England."
	end

	if t_england == 8 #rathstar sent
		message << "\n\nOur illustrious President mowglee, having been reminded to take his pills by the on-call Oncologist namyzarc in round 1, decided it would be best to remain in England, and it is good he did for the bomber rathstar (who met with his chemical engineer varoan in round 4) travelled abroad to Ruritania whereupon he promptly exploded, no doubt taking a few ModBots with him.\n\nBLUE TEAM WINS!"
	elsif t_england == 12 #mowglee sent
		message << "\n\nOur illustrious President mowglee, having been reminded to take his pills by the on-call Oncologist namyzarc in round 1, decided it would be best to travel abroad, and it is good he did for the bomber rathstar (whose chemical engineer varoan repaired his bomb in round 4) remained in England. Shortly after mowglee left, rathstar promptly exploded, no doubt taking a few ModBots with him, but mowglee is safe.\n\nBLUE TEAM WINS!"
	else
		message << "\n\nOur illustrious President mowglee, having been reminded to take his pills by the on-call Oncologist namyzarc in round 1, decided it would be best to remain in England, but unfortunately for him the bomber rathstar (whose chemical engineer varoan made sure to repair) exploded, and mowglee was no more. Sources report a few ModBots likely died in the explosion as well.\n\nRED TEAM WINS!"
	end

	message << "[/color][/b]"

	message << "\n\nThanks to everyone for playing, and for bearing with me as I tried to fight wih my ModBot and get it to work.\nI'm sorry that the game turned out to be very boring; I think Mach was correct that the reason was because there were no roles that punished card shares. It was my first time modding, and I'll know better for next time.\n\nThanks again to everyone for playing! I'll have a few more comments to make, probably tomorrow, once I get a chance to post."

	message << "\n\nI feel I made a few bad rules clarifications. I'm not sure I like forcing the painters to paint when they card share; it was what I had in mind when I started the game, but apparently Borgoto and Machiavellian did not. I'm sorry again for that late clarification that I think messed up both of you.\nBoth scholars knew their own team's vacuum and the opposing team's wallflower. I found it interesting that Shawna began by claiming both she and square were blue--I don't really know whether anyone believed that or anything, but I think there are some interesting strategies with the scholar. I wish now that I had included a role that had a penalty for card sharing instead of the scholar, but such is life."

	message << "\n\nA few special notes for now: namyzarc's \"on-call Oncologist\" song was amazing, and I think he likely had the most public reveals as well.\nrathstar tried to break modbot's vote-scanning in many varied ways, and as such will be featured in a section entitled \"Don't Be Like Rathstar\" indicating how to properly use the modbot. He also managed to vacuum his bomb. longlivesquare has some explosive indigestion."

	message << "\n\nFinally, as much as I hate to say it, thanks to modkiwi for counting all those votes and all his snarky comments. My favorite part was when Borgoto offered to paint him like me so that he could kill me and take my place. I am, of course, glad that did not actually happen. Then again, no one would know if I really were ModBot replacing Kiwi..."

	puts message
	$wi.post(1138843, message)
ensure
	$wi.stop
end
