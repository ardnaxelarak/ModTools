#!/usr/bin/ruby

require_relative 'Game'
require_relative 'Scan'

class BotRes < Game
	attr_accessor :roundnum, :index
	attr_accessor :gid, :name, :thread, :hidden

	def initialize(gid)
		super(gid)
	end

	def start_game
		res = $conn.query("SELECT pid FROM game_players WHERE gid = #{@gid}")
		list = []
		for row in res
			list.push(row[0].to_i)
		end
		list.shuffle!
		res = $conn.query("SELECT g.role, r.team, r.name FROM game_roles g JOIN roles r ON g.role = r.id WHERE g.gid = #{@gid}")
		roles = []
		for row in res
			roles.push([row[0].to_i, row[1].to_i], row[2])
		end
		roles.shuffle!
		unless list.length == roles.length
			puts "Game #{gid}: Number of players and number of roles do not agree"
			return
		end
		$conn.query("INSERT INTO turn_order (gid, pid) VALUES #{list.collect{|pid| "(#{@gid}, #{pid})"}.join(", ")}")
		num = list.length
		nums = (0...num).collect{|i| i}
		role_hash = {}
		for i in nums
			role_hash[list[i]] = roles[i]
		end
		$conn.query("INSERT INTO player_roles (gid, pid, role) VALUES #{role_hash.collect{|pid, roleinfo| "(#{@gid}, #{pid}, #{roleinfo[0]})"}.join(", ")}")
		role_messages = {}
		merlin_sees = list.select{|pid| role_hash[pid][1] == Constants::SPY_TEAM && role_hash[pid][0] != Constants::MORDRED}.sort_by{|pid| $pl[pid].name.upcase}
		spies_see = list.select{|pid| role_hash[pid][1] == Constants::SPY_TEAM && role_hash[pid][0] != Constants::OBERON}.sort_by{|pid| $pl[pid].name.upcase}
		for role_hash.each do |pid, roleinfo|
			case rid
			when Constants::MERLIN
				role_messages[pid] = "You are [b]Merlin[/b].\nThe spies are #{name_list(merlin_sees, false)}."
			when Constants::PERCY
				merlins = list.select{|pid| role_hash[pid][0] == Constants::MERLIN}
				morganas = list.select{|pid| role_hash[pid][0] == Constants::MORGANA}
				if (merlins.length == 0 && morganas.length == 0)
					role_messages[pid] = "You are [b]Percival[/b].\nNo one is Merlin or Morgana."
				elsif (merlins.length == 0)
					role_messages[pid] = "You are [b]Percival[/b].\n#{name_list(morganas.sort_by{|pid| $pl[pid].name.upcase}, true)} Morgana."
				elsif (morganas.length == 0)
					role_messages[pid] = "You are [b]Percival[/b].\n#{name_list(merlins.sort_by{|pid| $pl[pid].name.upcase}, true)} Merlin."
				else
					role_messages[pid] = "You are [b]Percival[/b].\n#{name_list((merlins + morganas).sort_by{|pid| $pl[pid].name.upcase}, true)} Merlin."
				end
			when Constants::REBEL
				role_messages[pid] = "You are a [b]Rebel[/b]."
			when Constants::MORGANA
				role_messages[pid] = "You are [b]Morgana[/b].\nThe other spies are #{name_list(spies_see, false)}."
			when Constants::MORDRED
				role_messages[pid] = "You are [b]Mordred[/b].\nThe other spies are #{name_list(spies_see, false)}."
			when Constants::ASSASSIN
				role_messages[pid] = "You are the [b]Assassin[/b].\nThe other spies are #{name_list(spies_see, false)}."
			when Constants::OBERON
				role_messages[pid] = "You are [b]Oberon[/b]."
			when Constants::SPY
				role_messages[pid] = "You are a [b]Spy[/b].\nThe other spies are #{name_list(spies_see, false)}."
			end
		end
		$conn.query("INSERT INTO player_messages (pid, gid, message) VALUES #{list.collect{|pid| "(#{pid}, #{@gid}, #{escape(role_messages[pid])})"}.join(", ")}")

		modmessage = "Turn order:\n"
		for pid in list
			modmessage << "#{$pl[pid].name} - #{role_hash[pid][2]}\n"
		end
		$conn.query("INSERT INTO player_messages (pid, gid, message) VALUES #{mod_list.collect{|pid| "(#{pid}, #{@gid}, #{escape(modmessage)})"}.join(", ")}")
		post = "[b][color=purple]Turn order:[/color][/b]\n"
		post << "[color=#008800]"
		post << list.collect{|pid| $pl[pid].name}.join("\n")
		post << "[/color]"
		$conn.query("UPDATE games SET status = #{Constants::ACTIVE} WHERE gid = #{@gid}")
		$wi.post(thread, post)
		# $wi.post(thread, "[color=purple][b]Roles have been sent out. Please await further instruction.[/b][/color]")
		puts "Started game #{@gid}"
		next_step
	end

	def update_status(prefix = nil)
		stat = status
		$wi.post(thread, "#{prefix ? "#{prefix}\n\n" : ""}#{stat}")
		$wi.edit_article(@status_id, "Current Status", stat) if @status_id
	end

	def status
		plist = turn_order
		num = plist.length
		res = $conn.query("SELECT round_num, phase_num, viewer, viewee, view_pos FROM games WHERE gid = #{@gid}")
		return nil unless row = res.fetch_row
		row.collect!{|piece| piece == nil ? nil : piece.to_i}
		(round_num, phase_num, viewer, viewee, view_pos) = row
		res = $conn.query("SELECT c.pid, r.name FROM player_cards c JOIN roles r ON c.card = r.id WHERE c.gid = #{@gid}")
		card_hash = {}
		for row in res
			card_hash[row[0].to_i] = row[1]
		end
		message = "[u][b]Current Table[/b][/u]\n"
		message << "Phase #{round_num >= 5 ? 4 : round_num - 1}"
		if (round_num == 1)
			if (viewer && viewee && view_pos)
				message << "\n#{$pl[viewer].name} is looking at #{$pl[viewee].name}'s #{POS_NAMES[view_pos]} card."
			else
				message << "\nWaiting for everyone to confirm readiness"
			end
		elsif (round_num == 2)
			message << "\nSkirmish-CM: #{$pl[viewee]}"
			cards = num_remaining(1)
			message << "\n#{cards} Benefit of the Doubt card(s) remain"
		elsif (round_num == 3)
			message << "\nSkirmish-CM: #{$pl[viewee]}"
			cards = num_remaining(2)
			message << "\n#{cards} Reliable card(s) remain"
		elsif (round_num == 4)
			message << "\nSkirmish-CM: #{$pl[viewee]}"
		elsif (round_num >= 5)
			message << "\nActive Player: #{$pl[phase_num]}"
		end
		if (round_num >= 2 && round_num <= 4)
			if (viewer && viewee && view_pos)
				message << "\n#{$pl[viewer].name} is looking at #{$pl[viewee].name}'s #{POS_NAMES[view_pos]} card."
			elsif (viewer && viewee)
				message << "\n#{$pl[viewer].name} is deciding which of #{$pl[viewee].name}'s cards to look at."
			elsif (viewee)
				message << "\nVoting to punch or protect #{$pl[viewee].name}."
			end
		elsif (round_num >= 5)
			if (viewer && viewee && view_pos)
				message << "\n#{$pl[viewer].name} is looking at #{$pl[viewee].name}'s #{POS_NAMES[view_pos]} card."
			elsif (viewer && viewee)
				message << "\n#{$pl[viewer].name} is deciding which of #{$pl[viewee].name}'s cards to look at."
			elsif (viewee)
				message << "\n#{$pl[phase_num].name} is deciding who should be given cockpit access."
			else
				message << "\n#{$pl[phase_num].name} is choosing a player to view another player's card."
			end
		end
		colors = COLOR_LIST
		color_hash = {}
		for i in 0...num
			color_hash[plist[i]] = colors[i]
		end

		cur_turn = -1
		cur_turn = plist[phase_num] if round_num >= 2 && round_num <= 4
		cur_turn = phase_num if round_num >= 5

		texts = []
		marker_hash = num_markers
		for i in 0...(num + 1) / 2
			text = "[center]"
			text << card_hash[plist[i]]
			text << "\n"
			text << "[color=white][bgcolor=#{colors[i]}][c] [/c]"
			text << "[b]" if plist[i] == cur_turn
			text << "#{i + 1}. #{$pl[plist[i]].name} (#{marker_hash[plist[i]] || 4})"
			text << "[/b]" if plist[i] == cur_turn
			text << "[c] [/c][/bgcolor][/color]"
			text << "\n"
			text << "[c][color=white][b][bgcolor=gray]  R  [/bgcolor] [bgcolor=gray]  M  [/bgcolor] [bgcolor=gray]  L  [/bgcolor][/b][/color][/c]"
			text << "\n"
			text << "[c][color=white][b]"
			text << (1..3).collect{|pos| knowledge_markers(plist[i], pos, color_hash).join}.join(" ")
			text << "[/b][/color][/c]"

			text << "\n"
			text << "[/center]"
			texts[i] = text
		end
		for i in (num + 1) / 2...num
			text = "[center]"
			text << "[c][color=white][b]"
			text << (1..3).collect{|pos| knowledge_markers(plist[i], pos, color_hash).reverse.join}.reverse.join(" ")
			text << "[/b][/color][/c]"
			text << "\n"
			text << "[c][color=white][b][bgcolor=gray]  L  [/bgcolor] [bgcolor=gray]  M  [/bgcolor] [bgcolor=gray]  R  [/bgcolor][/b][/color][/c]"
			text << "\n"
			text << "[color=white][bgcolor=#{colors[i]}][c] [/c]"
			text << "[b]" if plist[i] == cur_turn
			text << "#{i + 1}. #{$pl[plist[i]].name} (#{marker_hash[plist[i]] || 4})"
			text << "[/b]" if plist[i] == cur_turn
			text << "[c] [/c][/bgcolor][/color]"
			text << "\n"
			text << card_hash[plist[i]]

			text << "\n"
			text << "[/center]"
			texts[i] = text
		end
		message << "\n\n[size=10]"
		for i in 0...num / 2
			message << "[floatleft]"
			message << texts[i]
			message << "\n"
			message << texts[-i - 1]
			message << "[/floatleft]"
		end
		if (num % 2 > 0)
			i = num / 2
			message << "[floatleft]"
			message << texts[i]
			message << "[/floatleft]"
		end
		message << "[c]#{" " * (22 * ((num + 1) / 2))}[/c]"
		message << "[/size][clear]"
		if (round_num >= 2 && round_num <= 4)
			if (viewee && viewer && view_pos)
				message << "\n\n#{$pl[viewer].name} has been sent #{$pl[viewee].name}'s #{POS_NAMES[view_pos]} card.\nPlease post either [b]Honest[/b] or [b]Infiltrator[/b] in the thread.\n(You must tell the truth if you are Honest)"
			elsif (viewee && viewer)
				message << "\n\n#{$pl[viewer].name} is deciding which of #{$pl[viewee].name}'s cards to view.\nPlease post [b]left[/b], [b]middle[/b], or [b]right[/b] in the thread."
			elsif (viewee)
				message << "\n\n[b]VOTE! Voting links: [url=http://boardgamegeek.com/geekmail/compose?touser=modkiwi&subject=MM%20PBF%20#{@index.gsub(" ", "%20")}%20-%20Protect%20#{$pl[viewee].name.gsub(" ", "%20")}][COLOR=#009900]Protect[/COLOR][/url] / [url=http://boardgamegeek.com/geekmail/compose?touser=modkiwi&subject=MM%20PBF%20#{@index.gsub(" ", "%20")}%20-%20Punch%20#{$pl[viewee].name.gsub(" ", "%20")}][COLOR=#FF0000]Punch[/COLOR][/url][/b]"
			end
		elsif (round_num == 1 && viewer && viewee && view_pos)
			message << "\n\n#{$pl[viewer].name} has been sent #{$pl[viewee].name}'s #{POS_NAMES[view_pos]} card.\nPlease post either [b]Honest[/b] or [b]Infiltrator[/b] in the thread.\n(You must tell the truth if you are Honest)"
		elsif (round_num >= 5)
			if (viewee && viewer && view_pos)
				message << "\n\n#{$pl[viewer].name} has been sent #{$pl[viewee].name}'s #{POS_NAMES[view_pos]} card.\nPlease post either [b]Honest[/b] or [b]Infiltrator[/b] in the thread.\n(You must tell the truth if you are Honest)"
			elsif (viewee && viewer)
				message << "\n\n#{$pl[viewer].name} is deciding which of #{$pl[viewee].name}'s cards to view.\nPlease post [b]left[/b], [b]middle[/b], or [b]right[/b] in the thread."
			elsif (viewee)
				message << "\n\n#{$pl[phase_num].name} is deciding who should be given cockpit access. Please post [b]choose [i]&lt;player&gt;[/i][/b] in the thread."
			else
				message << "\n\n#{$pl[phase_num].name} is choosing a player to view another player's card. Please post [b][i]&lt;player&gt;[/i] checks [i]&lt;player&gt;[/i][/b] in the thread. You may not choose the Captain or a player with cockpit access.\n(You may instead post [b]choose [i]&lt;player&gt;[/i][/b] to skip the check and choose a player to give cockpit access immediately.)"
			end
		end
		return message
	end

	def send_lady
		res = $conn.query("SELECT pr.role, t.name, g.viewer, g.viewee FROM player_roles pr JOIN games g ON pr.gid = g.gid JOIN roles r ON pr.role = r.id JOIN teams t ON r.appear = t.id WHERE g.gid = #{@gid} AND pr.pid = g.viewee")
		return unless row = res.fetch_row
		(role, team, viewer, viewee) = row
		role = role.to_i if role
		viewer = viewer.to_i if viewer
		viewee = viewee.to_i if viewee

		message = "#{$pl[viewee].name} is a [b]#{team}[/b]."
		$conn.query("INSERT INTO player_messages (pid, gid, message) VALUES (#{viewer}, #{@gid}, #{escape(message)})")
	end

	def next_step
		res = $conn.query("SELECT round_num, phase_num, viewer, viewee, view_pos FROM games WHERE gid = #{@gid}")
		return unless row = res.fetch_row
		row.collect!{|piece| piece == nil ? nil : piece.to_i}
		(round_num, phase_num, viewer, viewee, view_pos) = row
		plist = turn_order
		num = plist.length
		if (round_num == 1)
			phase_num += 1
			if (phase_num > (2 * num + 1))
				# move into phase 1
				round_num = 2
				phase_num = num - 1
				viewee = nil
			else
				viewer = plist[phase_num / 2 - 1]
				viewee = plist[(phase_num / 2 - 2 + 2 * (phase_num % 2)) % num]
				view_pos = 3 - 2 * (phase_num % 2)
				$conn.query("UPDATE games SET phase_num = #{phase_num}, viewer = #{viewer}, viewee = #{viewee}, view_pos = #{view_pos} WHERE gid = #{@gid}")
				send_view
				update_status
			end
		end
		if (round_num >= 2 && round_num <= 4)
			if viewee
				viewer = nil
				$conn.query("UPDATE games SET viewer = NULL WHERE gid = #{@gid}")
				vote(viewee, true)
				update_status
			else
				unless (pos = get_next_pos(plist, phase_num, round_num - 1))
					next_step unless check_end(round_num + 1) # add one because it was increased in the database
					return
				end
				return if pos == -1
				phase_num = pos
				viewee = plist[pos]
				viewer = get_viewer(pos, round_num - 1)
				if viewer
					view_pos = nil
					$conn.query("UPDATE games SET round_num = #{round_num}, phase_num = #{phase_num}, viewee = #{viewee}, viewer = #{viewer}, view_pos = NULL WHERE gid = #{@gid}")
					update_status
				else
					$conn.query("UPDATE games SET round_num = #{round_num}, phase_num = #{phase_num}, viewee = #{viewee}, viewer = NULL, view_pos = NULL WHERE gid = #{@gid}")
					$wi.post(thread, "[color=#008800]No one is able to view one of #{$pl[viewee].name}'s cards.[/color]")
					next_step
				end
			end
		elsif (round_num >= 5 + num / 2)
			end_game(true, "All honest players have been given cockpit access.")
		elsif (round_num >= 5)
			if (viewer && viewee && view_pos)
				$conn.query("UPDATE games SET viewer = NULL, view_pos = NULL WHERE gid = #{@gid}")
			end
			update_status
		end
	end

	def scan(verbose = false, only_new = true)
		scan_Res(verbose, only_new)
		check_votes if check_Res_mail(verbose)
	end

	def scan_Res(verbose = false, only_new = true)
		last = nil
		res = $conn.query("SELECT last_scanned, phase_num, viewer, viewee, view_pos FROM games WHERE gid = #{@gid}")
		return unless row = res.fetch_row
		row.collect!{|piece| piece == nil ? nil : piece.to_i}
		(last_id, phase_num, viewer, viewee, view_pos) = row
		last = last_id if only_new
		list = $wi.get_posts(thread, last)
		return if list.length <= 0
		$conn.query("UPDATE games SET last_scanned = #{list.last[:id]} WHERE gid = #{@gid}")
		actions = action_list(list, ACTION_HASH)
		for action in actions
			if (action[1] == :status)
				$wi.post(thread, status)
				next
			end
			next unless actor = $pl.get_player(action[0], turn_order, verbose)
			if (viewer && viewee)
				next unless actor == viewer
				case action[1]
				when :honest
					if (view_pos)
						viewed(viewer, viewee, view_pos, true)
						puts "#{$pl[viewer].name} viewed #{$pl[viewee].name}'s #{POS_NAMES[view_pos]} card as Honest" if verbose
					end
				when :infiltrator
					if (view_pos)
						viewed(viewer, viewee, view_pos, false)
						puts "#{$pl[viewer].name} viewed #{$pl[viewee].name}'s #{POS_NAMES[view_pos]} card as Infiltrator" if verbose
					end
				when :left
					unless (view_pos)
						choose(3)
						puts "#{$pl[viewer].name} has chosen to view #{$pl[viewee].name}'s #{POS_NAMES[3]} card" if verbose
					end
				when :middle
					unless (view_pos)
						choose(2)
						puts "#{$pl[viewer].name} has chosen to view #{$pl[viewee].name}'s #{POS_NAMES[2]} card" if verbose
					end
				when :right
					unless (view_pos)
						choose(1)
						puts "#{$pl[viewer].name} has chosen to view #{$pl[viewee].name}'s #{POS_NAMES[1]} card" if verbose
					end
				end
			else
				next unless round_num >= 5
				next unless actor == phase_num
				if (action[1] == :check && !viewee)
					next unless action.length >= 5
					vl = valid_lookers
					viewer = $pl.get_player(action[3], vl, verbose)
					viewee = $pl.get_player(action[4], vl, verbose)
					if (viewer && viewee)
						$wi.post(thread, "[color=#008800]#{$pl[phase_num].name} has chosen for #{$pl[viewer].name} to view one of #{$pl[viewee].name}'s cards.[/color]")
						$conn.query("UPDATE games SET viewer = #{viewer}, viewee = #{viewee} WHERE gid = #{@gid}")
						update_status
					else
						$wi.post(thread, "[q=\"#{action[0]}\"]#{action[2]}[/q]\n[color=#008800]This choice is invalid.[/color]")
						next
					end
				elsif (action[1] == :choose)
					vl = valid_lookers
					choice = $pl.get_player(action[3], vl, verbose)
					if (choice)
						ren = $conn.query("SELECT r.role FROM player_roles r WHERE r.pid = #{choice} AND r.gid = #{@gid}")
						return false unless row = ren.fetch_row
						role = row[0].to_i
						if (role == Constants::INFILTRATOR)
							end_game(false, "#{$pl[choice].name} is an infiltrator.")
							return true
						end
						$wi.post(thread, "[color=#008800]#{$pl[choice].name} is Honest.[/color]")
						$conn.query("UPDATE player_cards SET card = #{Constants::COCKPIT} WHERE gid = #{@gid} AND pid = #{choice}")
						$conn.query("UPDATE games SET round_num = #{round_num + 1}, phase_num = #{choice}, viewer = NULL, viewee = NULL, view_pos = NULL WHERE gid = #{@gid}")
						next_step
					else
						$wi.post(thread, "[q=\"#{action[0]}\"]#{action[2]}[/q]\n[color=#008800]This choice is invalid.[/color]")
						next
					end
				end
			end
		end
	end

	def check_Res_mail(verbose = false)
		res = $conn.query("SELECT viewee FROM games WHERE gid = #{@gid}")
		return false unless row = res.fetch_row
		return false unless row[0]
		viewee = row[0].to_i
		list = $wi.geekmail_list(nil, true)
		return false if list.length <= 0

		ret = false

		pattern = /MM +(?:PBF *)?(?:#)?#{@index}.*(protect|punch) +(.*)/i
		for item in list
			if (match = item[:subject].match(pattern))
				$wi.get_geekmail(item[:id])
				next unless ($pl.get_player(match[2], nil, verbose) == viewee)
				next unless actor = $pl.get_player(item[:from], turn_order, verbose)
				if (match[1].downcase == "punch")
					vote(actor, false)
					puts "#{$pl[actor].name} punches #{$pl[viewee].name}" if verbose
				else
					vote(actor, true)
					puts "#{$pl[actor].name} protects #{$pl[viewee].name}" if verbose
				end
				ret = true
			end
		end
		return ret
	end

	def check_end(round_num)
		case round_num
		when 4
			ren = $conn.query("SELECT c.pid FROM player_cards c LEFT JOIN player_roles r ON c.pid = r.pid WHERE c.card = #{Constants::RELIABLE} AND r.role = #{Constants::HONEST}")
			return false if ren.num_rows > 0
			end_game(false, "All Reliable players are infiltrators.")
			return true
		when 5
			ren = $conn.query("SELECT c.pid, r.role FROM player_cards c LEFT JOIN player_roles r ON c.pid = r.pid WHERE c.card = #{Constants::CAPTAIN}")
			return false unless row = ren.fetch_row
			(pid, role) = row
			pid = pid.to_i if pid
			role = role.to_i if role
			if (role == Constants::INFILTRATOR)
				end_game(false, "#{$pl[pid].name} is an infiltrator.")
				return true
			end
			$wi.post(thread, "[color=#008800]#{$pl[pid].name} is Honest.[/color]")
			$conn.query("UPDATE games SET phase_num = #{pid}, viewer = NULL, viewee = NULL, view_pos = NULL WHERE gid = #{@gid}")
			return false
		end
		false
	end

	def end_game(good_win, message = nil)
		text = ""
		text << "[color=#008800]#{message}[/color]\n\n" if message
		if (good_win)
			text << "[color=purple][b]Honest Crewmembers win![/b][/color]"
		else
			text << "[color=purple][b]Infiltrators win![/b][/color]"
		end
		$wi.post(thread, text)
		$conn.query("UPDATE games SET status = #{Constants::ENDED} WHERE gid = #{gid}")
	end

	def viewed(viewer, viewee, view_pos, honest)
		$conn.query("INSERT INTO role_views (gid, pid, position, viewer, role) VALUES (#{@gid}, #{viewee}, #{view_pos}, #{viewer}, #{honest ? Constants::HONEST : Constants::INFILTRATOR})")
		$wi.post(thread, "[color=#008800]#{$pl[viewer].name} claims #{$pl[viewee].name}'s #{POS_NAMES[view_pos]} card says [b]#{honest ? "Honest" : "Infiltrator"}[/b][/color]")
		next_step
	end

	def choose(view_pos)
		$conn.query("UPDATE games SET view_pos = #{view_pos} WHERE gid = #{@gid}")
		send_view
		update_status
	end

	def vote(p1, protect)
		$conn.query("CALL Vote(#{@gid}, #{p1}, #{protect ? "TRUE" : "FALSE"})")
	end

	def check_votes
		plist = turn_order
		num = plist.length
		res = $conn.query("SELECT round_num, phase_num, viewee FROM games WHERE gid = #{@gid}")
		return unless row = res.fetch_row
		row.collect!{|piece| piece == nil ? nil : piece.to_i}
		(round_num, phase_num, viewee) = row
		res = $conn.query("SELECT v.pid, vote FROM binary_votes v JOIN turn_order t ON v.gid = t.gid AND v.pid = t.pid WHERE gid = #{@gid} AND round_num = #{round_num} AND phase_num = #{phase_num} ORDER BY t.id")
		return if res.num_rows < num
		text = "[b]Phase #{round_num - 1} - #{$pl[viewee].name}[/b]\n"
		count = 0
		for row in res
			if (pid = row[0].to_i) != viewee
				text << "#{$pl[pid].name} - "
				if row[1].to_i > 0
					text <<  "[color=#009900]Protect[/color]\n"
					count += 1
				else
					text << "[color=#FF0000]Punch[/color]\n"
				end
			end
		end
		text << "[color=purple][b]"
		if count >= num / 2
			text << "\n#{$pl[viewee]} has received a #{["Benefit of the Doubt", "Reliable", "Captain"][round_num - 2]} card."
			$conn.query("UPDATE player_cards SET card = #{42 + round_num} WHERE gid = #{@gid} AND pid = #{viewee}")
		else
			text << "\n#{$pl[viewee]} has been Punched."
			$conn.query("UPDATE player_cards SET card = #{Constants::PUNCHED} WHERE gid = #{@gid} AND pid = #{viewee}")
		end
		text << "[/b][/color]"
		add_to_history(text)
		$conn.query("UPDATE games SET viewee = NULL WHERE gid = #{@gid}")
		next_step
	end

	def replace(oldid, newid)
		$conn.query("UPDATE game_players SET pid = #{newid} WHERE gid = #{@gid} AND pid = #{oldid}")
		$conn.query("UPDATE turn_order SET pid = #{newid} WHERE gid = #{@gid} AND pid = #{oldid}")
		$conn.query("UPDATE player_cards SET pid = #{newid} WHERE gid = #{@gid} AND pid = #{oldid}")
		$conn.query("UPDATE player_roles SET pid = #{newid} WHERE gid = #{@gid} AND pid = #{oldid}")
		$conn.query("UPDATE role_cards SET pid = #{newid} WHERE gid = #{@gid} AND pid = #{oldid}")
		$conn.query("UPDATE role_views SET pid = #{newid} WHERE gid = #{@gid} AND pid = #{oldid}")
		$conn.query("UPDATE role_views SET viewer = #{newid} WHERE gid = #{@gid} AND viewer = #{oldid}")
		res = $conn.query("SELECT round_num, phase_num FROM games WHERE gid = #{@gid}")
		return unless row = res.fetch_row
		(round_num, phase_num) = row
		$conn.query("DELETE FROM binary_votes WHERE gid = #{@gid} AND round_num = #{round_num} AND phase_num = #{phase_num} AND pid = #{oldid}")
	end
end
