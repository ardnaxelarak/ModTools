#!/usr/bin/ruby

require_relative 'Game'
require_relative 'Scan'

class BotMM < Game
	attr_accessor :roundnum, :index
	attr_accessor :gid, :name, :thread, :hidden

	POS_NAMES = ["", "right", "middle", "left"]
	COLOR_LIST = ["red", "green", "blue", "orange", "brown", "purple", "black"]

	ACTION_HASH = {:left => "left", :right => "right", :middle => "middle|center", :honest => "honest", :infiltrator => "infiltrator", :status => "status", :check => "%p checks? %p", :choose => "choose %p"}

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
		$conn.query("INSERT INTO turn_order (gid, pid) VALUES #{list.collect{|pid| "(#{@gid}, #{pid})"}.join(", ")}")
		$conn.query("INSERT INTO player_cards (gid, pid, card) VALUES #{list.collect{|pid| "(#{@gid}, #{pid}, #{Constants::CREWMEMBER})"}.join(", ")}")
		num = list.length
		bad = (num - 1) / 2
		good = num - bad
		roles = [Constants::HONEST] * good + [Constants::INFILTRATOR] * bad
		roles.shuffle!
		nums = (0...num).collect{|i| i}
		$conn.query("INSERT INTO player_roles (gid, pid, role) VALUES #{nums.collect{|ind| "(#{@gid}, #{list[ind]}, #{roles[ind]})"}.join(", ")}")
		badmessage = "[b]You are an Infiltrator.[/b]\nThe infilitrators are #{name_list(nums.select{|ind| roles[ind] == Constants::INFILTRATOR}.collect{|ind| list[ind]})}."
		goodmessage = "[b]You are Honest.[/b]"
		$conn.query("INSERT INTO player_messages (pid, gid, message) VALUES #{nums.collect{|ind| "(#{list[ind]}, #{@gid}, #{escape(roles[ind] == Constants::HONEST ? goodmessage : badmessage)})"}.join(", ")}")

		cards = []
		for i in nums
			cards[i] = [Constants::HONEST, Constants::INFILTRATOR, roles[i]]
			cards[i].shuffle!
			$conn.query("INSERT INTO role_cards (gid, pid, position, role) VALUES #{(0...3).collect{|j| "(#{@gid}, #{list[i]}, #{j + 1}, #{cards[i][j]})"}.join(", ")}")
		end
		modmessage = "Turn order:\n"
		for pid in list
			modmessage << "#{$pl[pid].name}\n"
		end
		modmessage << "\n\nInfiltrators are #{name_list(nums.select{|ind| roles[ind] == Constants::INFILTRATOR}.collect{|ind| list[ind]})}."
		modmessage << "\n\n[c]R M L Cards"
		for i in nums
			modmessage << "\n#{cards[i].collect{|rid| rid == Constants::HONEST ? "H" : "I"}.join(" ")} #{$pl[list[i]].name}"
		end
		modmessage << "[/c]"
		$conn.query("INSERT INTO player_messages (pid, gid, message) VALUES #{mod_list.collect{|pid| "(#{pid}, #{@gid}, #{escape(modmessage)})"}.join(", ")}")
		$conn.query("UPDATE games SET status = #{Constants::ACTIVE} WHERE gid = #{@gid}")
		$wi.post(thread, "[color=purple][b]Roles have been sent out. Please await further instruction.[/b][/color]")
		puts "Started game #{@gid}"
	end

	def can_view(viewer, viewee)
		res = $conn.query("SELECT pid FROM role_views WHERE gid = #{@gid} AND viewer = #{viewer}")
		return false if res.num_rows >= 4
		for row in res
			return false if row[0].to_i == viewee
		end
		return true
	end

	def num_markers
		res = $conn.query("SELECT viewer, count(*) FROM role_views WHERE gid = #{@gid} GROUP BY viewer")
		hash = {}
		for row in res
			hash[row[0].to_i] = 4 - row[1].to_i
		end
		return hash
	end

	def get_viewer(position, phase)
		plist = turn_order
		num = plist.length
		pos = position + num / 2
		case phase
		when 2
			pos += 1
		when 3
			pos -= 1 if num > 5
		end
		pos = pos % num
		return plist[pos] if can_view(plist[pos], plist[position])
		pos -= 1
		return plist[pos] if can_view(plist[pos], plist[position])
		pos = (pos + 2) % num
		return plist[pos] if can_view(plist[pos], plist[position])
		return nil
	end

	def knowledge_markers(pid, position, colorhash)
		res = $conn.query("SELECT v.viewer, v.role, r.name FROM role_views v LEFT JOIN roles r ON v.role = r.id WHERE v.gid = #{@gid} AND v.pid = #{pid} AND v.position = #{position} ORDER BY v.id")
		num = 5 - res.num_rows
		pieces = []
		for row in res
			pl = row[0].to_i
			col = colorhash[pl]
			let = row[2][0]
			pieces.push("[bgcolor=#{col}]#{let}[/bgcolor]")
		end
		pieces.push("[bgcolor=white]#{" " * num}[/bgcolor]") if num > 0
		return pieces
	end

	def num_remaining(phase)
		case phase
		when 1
			card = Constants::BENEFIT
			total = (turn_order.length + 1) / 2
		when 2
			card = Constants::RELIABLE
			total = 2
		when 3
			card = Constants::CAPTAIN
			total = 1
		end
		row = $conn.query("SELECT count(*) FROM player_cards WHERE gid = #{@gid} AND card = #{card}").fetch_row
		return total - row[0].to_i
	end

	def get_next_pos(plist, pos, phase)
		num = plist.length
		case phase
		when 1
			current = Constants::CREWMEMBER
			new = Constants::BENEFIT
			total = (num + 1) / 2
			card_name = "Benefit of the Doubt"
		when 2
			current = Constants::BENEFIT
			new = Constants::RELIABLE
			total = 2
			card_name = "Reliable"
		when 3
			current = Constants::RELIABLE
			new = Constants::CAPTAIN
			total = 1
			card_name = "Captain"
		end
		res = $conn.query("SELECT pid, card FROM player_cards WHERE gid = #{@gid}")
		card_hash = {}
		cur_left = []
		new_taken = []
		for row in res
			card_hash[row[0].to_i] = row[1].to_i
			if (row[1].to_i == current )
				cur_left.push(row[0].to_i)
			elsif (row[1].to_i == new)
				new_taken.push(row[0].to_i)
			end
		end
		if (total - new_taken.length == 0)
			$conn.query("UPDATE player_cards SET card = #{Constants::PUNCHED} WHERE gid = #{@gid} AND card = #{current}")
			$conn.query("UPDATE games SET round_num = round_num + 1 WHERE gid = #{@gid}")
			message = "#{name_list(cur_left)} automatically become#{cur_left.length > 1 ? "" : "s"} Punched."
			$wi.post(thread, "[color=#008800]#{message}[/color]")
			return nil
		end
		if (total - new_taken.length == cur_left.length)
			$conn.query("UPDATE player_cards SET card = #{new} WHERE gid = #{@gid} AND card = #{current}")
			$conn.query("UPDATE games SET round_num = round_num + 1 WHERE gid = #{@gid}")
			message = "#{name_list(cur_left)} automatically receive#{cur_left.length > 1 ? "" : "s"} a #{card_name} card."
			$wi.post(thread, "[color=#008800]#{message}[/color]")
			return nil
		end
		newpos = (pos + 1) % num
		while (card_hash[plist[newpos]] != current && newpos != pos)
			newpos = (newpos + 1) % num
		end
		return newpos if (newpos != pos || card_hash[plist[newpos]] == new)
		$wi.post(thread, "[color=#008800]Something weird happened.[/color]")
		return -1
	end

	def valid_lookers
		res = $conn.query("SELECT pid FROM player_cards WHERE gid = #{@gid} AND card NOT IN (#{Constants::CAPTAIN}, #{Constants::COCKPIT})")
		ret = []
		for row in res
			ret.push(row[0].to_i) if row[0]
		end
		return ret
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
			text << "#{i + 1}. #{$pl[plist[i]].name} (#{marker_hash[plist[i]]})"
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
			text << "#{i + 1}. #{$pl[plist[i]].name} (#{marker_hash[plist[i]]})"
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
		message << "[c]#{" " * (20 * ((num + 1) / 2))}[/c]"
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
				message << "\n\n#{$pl[phase_num].name} is choosing a player to view another player's card. Please post [b][i]&lt;player&gt;[/i] checks [i]&lt;player&gt;[/i][/b] in the thread. You may not choose the Captain or a player with cockpit access."
			end
		end
		return message
	end

	def send_view
		res = $conn.query("SELECT g.viewer, g.viewee, g.view_pos, r1.name, pr.role FROM games g LEFT JOIN player_roles pr ON pr.gid = g.gid AND pr.pid = g.viewer LEFT JOIN role_cards c ON c.gid = g.gid AND c.pid = g.viewee AND c.position = g.view_pos LEFT JOIN roles r1 ON c.role = r1.id WHERE g.gid = #{@gid}")
		return unless row = res.fetch_row
		(viewer, viewee, view_pos, view, viewerloyalty) = row
		viewer = viewer.to_i if viewer
		viewee = viewee.to_i if viewee
		view_pos = view_pos.to_i if view_pos
		viewerloyalty = viewerloyalty.to_i if viewerloyalty

		message = "#{$pl[viewee].name}'s #{POS_NAMES[view_pos]} card says [b]#{view}[/b].\n"
		if (viewerloyalty == Constants::HONEST)
			message << "Since you are Honest, you must tell the truth.\nPlease post [b]#{view}[/b] in the thread."
		else
			message << "Please post either [b]Honest[/b] or [b]Infiltrator[/b] in the thread according to the claim you wish to make."
		end
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
				message = status
				$wi.post(thread, message)
			end
		end
		if (round_num >= 2 && round_num <= 4)
			if viewee
				viewer = nil
				$conn.query("UPDATE games SET viewer = NULL WHERE gid = #{@gid}")
				vote(viewee, true)
				message = status
				$wi.post(thread, message)
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
					message = status
					$wi.post(thread, message)
				else
					$conn.query("UPDATE games SET round_num = #{round_num}, phase_num = #{phase_num}, viewee = #{viewee}, viewer = NULL, view_pos = NULL WHERE gid = #{@gid}")
					$wi.post(thread, "[color=#008800]No one is able to view one of #{$pl[viewee].name}'s cards.[/color]")
					next_step
				end
			end
		elsif (round_num >= 5 + num / 2)
			end_game(true, "All honest players have been given cockpit access.")
		elsif (round_num >= 5)
			$wi.post(thread, status)
		end
	end

	def scan(verbose = false, only_new = true)
		scan_MM(verbose, only_new)
		check_votes if check_MM_mail(verbose)
	end

	def scan_MM(verbose = false, only_new = true)
		last = nil
		res = $conn.query("SELECT last_scanned, viewer, viewee, view_pos FROM games WHERE gid = #{@gid}")
		return unless row = res.fetch_row
		row.collect!{|piece| piece == nil ? nil : piece.to_i}
		(last_id, viewer, viewee, view_pos) = row
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
						$wi.post(thread, status)
					else
						$wi.post(thread, "[q=\"#{action[0]}\"]#{action[2]}[/q]\n[color=#008800]This choice is invalid.[/color]")
						next
					end
				elsif (action[1] == :choose && viewee)
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

	def check_MM_mail(verbose = false)
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
					puts "#{$pl[actor].name} punches #{$pl[viewee].name}"
				else
					vote(actor, true)
					puts "#{$pl[actor].name} protects #{$pl[viewee].name}"
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
		message = status
		$wi.post(thread, message)
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
		res = $conn.query("SELECT pid, vote FROM binary_votes WHERE gid = #{@gid} AND round_num = #{round_num} AND phase_num = #{phase_num}")
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
		$wi.post(thread, text)
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
