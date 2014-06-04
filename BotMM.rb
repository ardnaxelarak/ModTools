#!/usr/bin/ruby

require_relative 'Setup'
require_relative 'Scan'

class BotMM
	attr_accessor :roundnum, :index
	attr_accessor :gid, :name, :thread, :hidden

	POS_NAMES = ["", "left", "middle", "right"]

	def initialize(gid)
		@gid = gid
		res = $conn.query("SELECT name, thread_id FROM games WHERE gid = #{@gid}")
		return unless row = res.fetch_row
		(@name, @thread) = row
	end

	def start_game
		res = $conn.query("SELECT pid FROM game_players WHERE gid = #{@gid}")
		list = []
		for row in res
			list.push(row[0].to_i)
		end
		list.shuffle!
		$conn.query("INSERT INTO turn_order (gid, pid) VALUES #{list.collect{|pid| "(#{@gid}, #{pid})"}.join(", ")}")
		$conn.query("INSERT INTO player_cards (gid, pid, card) VALUES #{list.collect{|pid| "(#{@gid}, #{pid}, 48)"}.join(", ")}")
		num = list.length
		bad = (num - 1) / 2
		good = num - bad
		roles = [42] * good + [43] * bad
		roles.shuffle!
		nums = (0...num).collect{|i| i}
		$conn.query("INSERT INTO player_roles (gid, pid, role) VALUES #{nums.collect{|ind| "(#{@gid}, #{list[ind]}, #{roles[ind]})"}.join(", ")}")
		badmessage = "[b]You are an Infiltrator.[/b]\nThe infilitrators are #{name_list(nums.select{|ind| roles[ind] == 43}.collect{|ind| list[ind]})}."
		goodmessage = "[b]You are Honest.[/b]"
		$conn.query("INSERT INTO player_messages (pid, gid, message) VALUES #{nums.collect{|ind| "(#{list[ind]}, #{@gid}, #{escape(roles[ind] == 42 ? goodmessage : badmessage)})"}.join(", ")}")

		cards = []
		for i in nums
			cards[i] = [42, 43, roles[i]]
			cards[i].shuffle!
			$conn.query("INSERT INTO role_cards (gid, pid, position, role) VALUES #{(0...3).collect{|j| "(#{@gid}, #{list[i]}, #{j + 1}, #{cards[i][j]})"}.join(", ")}")
		end
		modmessage = "Turn order:\n"
		for pid in list
			modmessage << "#{$pl[pid].name}\n"
		end
		modmessage << "\n\nInfiltrators are #{name_list(nums.select{|ind| roles[ind] == 43}.collect{|ind| list[ind]})}."
		modmessage << "\n\n[c]1 2 3 Cards"
		for i in nums
			modmessage << "\n#{cards[i].collect{|rid| rid == 42 ? "H" : "I"}.join(" ")} #{$pl[list[i]].name}"
		end
		modmessage << "[/c]"
		$conn.query("INSERT INTO player_messages (pid, gid, message) VALUES #{mod_list.collect{|pid| "(#{pid}, #{@gid}, #{escape(modmessage)})"}.join(", ")}")
		$conn.query("UPDATE games SET status = 3 WHERE gid = #{@gid}")
		$wi.post(thread, "[color=purple][b]Roles have been sent out. Please await further instruction.[/b][/color]")
		puts "Started game #{@gid}"
	end

	def all_players
		res = $conn.query("SELECT pid FROM turn_order WHERE gid = #{@gid} ORDER BY id")
		list = []
		for row in res
			list.push(row[0].to_i)
		end
		return list
	end

	def color_list
		return ["red", "green", "blue", "orange", "brown", "purple", "black"]
	end

	def mod_list
		res = $conn.query("SELECT pid FROM moderators WHERE gid = #{@gid}")
		list = []
		for row in res
			list.push(row[0].to_i)
		end
		return list
	end

	def name_list(pids, verb = false)
		return "" if pids.length == 0
		return "#{$pl[pids[0]].name}#{verb ? " is" : ""}" if pids.length == 1
		return "#{pids.collect{|pid| $pl[pid].name}.join{" and "}}#{verb ? " are" : ""}" if pids.length == 2
		return "#{pids[0...-1].collect{|pid| $pl[pid].name}.join(", ")}, and #{$pl[pids[-1]].name}#{verb ? " are" : ""}"
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

	def status
		plist = all_players
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
		message << "Phase #{round_num - 1}\n"
		if (round_num == 1)
			if (viewer == nil || viewee == nil)
				message << "Waiting for everyone to confirm readiness"
			else
				message << "#{$pl[viewer].name} is looking at #{$pl[viewee].name}'s #{POS_NAMES[view_pos]} card."
			end
		elsif (round_num == 2)
		end
		colors = color_list
		color_hash = {}
		for i in 0...num
			color_hash[plist[i]] = colors[i]
		end
		texts = []
		for i in 0...(num + 1) / 2
			text = "[center]"
			text << card_hash[plist[i]]
			text << "\n"
			text << "[color=white][bgcolor=#{colors[i]}][c] [/c]#{i + 1}. #{$pl[plist[i]].name}[c] [/c][/bgcolor][/color]"
			text << "\n"
			text << "[c][color=white][b][bgcolor=gray]  L  [/bgcolor] [bgcolor=gray]  M  [/bgcolor] [bgcolor=gray]  R  [/bgcolor][/b][/color][/c]"
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
			text << "[c][color=white][b][bgcolor=gray]  R  [/bgcolor] [bgcolor=gray]  M  [/bgcolor] [bgcolor=gray]  L  [/bgcolor][/b][/color][/c]"
			text << "\n"
			text << "[color=white][bgcolor=#{colors[i]}][c] [/c]#{i + 1}. #{$pl[plist[i]].name}[c] [/c][/bgcolor][/color]"
			text << "\n"
			text << card_hash[plist[i]]

			text << "\n"
			text << "[/center]"
			texts[i] = text
		end
		message << "\n\n[size=12]"
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
		message << "[/size][clear]"
		return message
	end

	def send_view
		res = $conn.query("SELECT g.viewer, g.viewee, g.view_pos, r1.name, pr.pid FROM games g LEFT JOIN player_roles pr ON pr.gid = g.gid AND pr.pid = g.viewer LEFT JOIN role_cards c ON c.gid = g.gid AND c.pid = g.viewee AND c.position = g.view_pos LEFT JOIN roles r1 ON c.role = r1.id WHERE g.gid = #{@gid}")
		return unless row = res.fetch_row
		(viewer, viewee, view_pos, view, viewerloyalty) = row
		viewer = viewer.to_i if viewer
		viewee = viewee.to_i if viewee
		view_pos = view_pos.to_i if view_pos
		viewerloyalty = viewerloyalty.to_i if viewerloyalty

		message = "#{$pl[viewee].name}'s #{POS_NAMES[view_pos]} card says [b]#{view}[/b].\n"
		if (viewerloyalty == 42)
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
		plist = all_players
		num = plist.length
		if (round_num == 1)
			phase_num += 1
			if (phase_num > (2 * num + 1))
				# move into phase 1
				round_num = 2
				phase_num = 1
			else
				viewer = plist[phase_num / 2 - 1]
				viewee = plist[(phase_num / 2 - 2 + 2 * (phase_num % 2)) % num]
				view_pos = 3 - 2 * (phase_num % 2)
				$conn.query("UPDATE games SET phase_num = #{phase_num}, viewer = #{viewer}, viewee = #{viewee}, view_pos = #{view_pos} WHERE gid = #{@gid}")
				send_view
				message = status
				message << "\n\n#{$pl[viewer].name} has been sent #{$pl[viewee].name}'s #{POS_NAMES[view_pos]} card.\nPlease post either [b]Honest[/b] or [b]Infiltrator[/b] in the thread.\n(You must tell the truth if you are Honest)"
				$wi.post(thread, message)
			end
		end
	end

	def scan(verbose = false, only_new = true)
		last = nil
		res = $conn.query("SELECT last_scanned, viewer, viewee, view_pos FROM games WHERE gid = #{@gid}")
		return unless row = res.fetch_row
		row.collect!{|piece| piece == nil ? nil : piece.to_i}
		(last_id, viewer, viewee, view_pos) = row
		last = last_id if only_new
		list = $wi.get_posts(thread, last)
		return if list.length <= 0
		$conn.query("UPDATE games SET last_scanned = #{list.last[:id]} WHERE gid = #{@gid}")
		actions = scan_actions(list)
		for action in actions
			next unless actor = $pl.get_player(action[0], all_players, verbose)
			next unless actor == viewer
			case action[1]
				when "honest"
					viewed(viewer, viewee, view_pos, true) if (view_pos)
					puts "#{$pl[viewer].name} viewed #{$pl[viewee].name}'s #{POS_NAMES[view_pos]} card as Honest" if verbose
				when "infiltrator"
					viewed(viewer, viewee, view_pos, false) if (view_pos)
					puts "#{$pl[viewer].name} viewed #{$pl[viewee].name}'s #{POS_NAMES[view_pos]} card as Honest" if verbose
			end
		end
	end

	def scan_actions(list)
		return if list.length <= 0
		actions = []
		pattern = /(honest|infiltrator|left|middle|right)/i
		for item in list
			for post in item[:posts]
				for action in post.scan(pattern)
					actions.push([item[:user], action[0].downcase])
				end
			end
		end
		actions
	end

	def viewed(viewer, viewee, view_pos, honest)
		$conn.query("INSERT INTO role_views (gid, pid, position, viewer, role) VALUES (#{@gid}, #{viewee}, #{view_pos}, #{viewer}, #{honest ? 42 : 43})")
		$wi.post(thread, "[color=#008800]#{$pl[viewer].name} claims #{$pl[viewee].name}'s #{POS_NAMES[view_pos]} card says [b]#{honest ? "Honest" : "Infiltrator"}[/b][/color]")
		next_step
	end

	def vote(p1, protect)
		$conn.query("CALL Vote(#{@gid}, #{p1}, #{protect ? "TRUE" : "FALSE"})")
		# check for next step
	end

	def change_round(num)
		$conn.query("UPDATE games SET round_num = #{num} WHERE gid = #{@gid}")
	end
end
