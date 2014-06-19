#!/usr/bin/ruby

require_relative 'Bot2r1b'
require_relative 'BotMM'
require_relative 'Scan'
require_relative 'Setup'

def check_active
	res = $conn.query("SELECT gid, g.tid, t.short_name, game_index, g.name, g.auto FROM games g LEFT JOIN statuses s ON g.status = s.sid LEFT JOIN game_types t ON g.tid = t.tid WHERE s.scan")

	for row in res
		(gid, tid, tsn, gind, name, auto) = row
		gid = gid.to_i
		tid = tid.to_i
		auto = auto.to_i > 0

		case tid
		when 1
			b = Bot2r1b.new(row[0].to_i)
			b.scan(false)
			b.tally(false, nil, false)
			# scan_transfers(b, true)
		when 5
			if (auto)
				b = BotMM.new(row[0].to_i)
				b.scan(false)
			end
		end
	end
end

def check_signups
	res = $conn.query("SELECT gid FROM games g LEFT JOIN statuses s ON g.status = s.sid WHERE s.signup")
	for row in res
		scan_signups(row[0].to_i, false)
	end
end

def check_others(verbose = false)
	check_mail(true)
	res = $conn.query("SELECT m.id, p.username, CONCAT(t.short_name, ' #', g.game_index, ': ', g.name) AS subject, message FROM player_messages m JOIN players p ON m.pid = p.pid JOIN games g ON m.gid = g.gid JOIN game_types t ON g.tid = t.tid")
	for row in res
		(m_id, username, subject, message) = row
		puts "Sending message to #{username} in #{subject}" if verbose
		$wi.send_geekmail(username, subject, message)
		$conn.query("DELETE FROM player_messages WHERE id = #{m_id}")
	end
	res = $conn.query("SELECT gid, status, signup_id, t.short_name, game_index, g.name FROM games g LEFT JOIN game_types t ON g.tid = t.tid WHERE g.signup_modified AND g.signup_id IS NOT NULL")
	for row in res
		(gid, status, article_id, tsn, gind, name) = row
		status = status.to_i
		puts "Updating player list for #{tsn} ##{gind}: #{name}" if verbose
		content = "[color=#008800]"
		content << "Player list according to ModKiwi:"
		pres = $conn.query("SELECT p.username FROM game_players g JOIN players p ON g.pid = p.pid WHERE g.gid = #{gid} ORDER BY p.username")
		num_rows = pres.num_rows
		for line in pres
			content << "\n#{line[0]}"
		end
		content << "\n\n#{num_rows} players are signed up."
		if (status == 2)
			content << "\n\nTo sign up for this game, post [b]signup[/b] in bold.\n"
			content << "To remove yourself from this game, post [b]remove[/b] in bold.\n"
			content << "You can also sign up at http://modkiwi.no-ip.biz/game/#{gid}"
		else
			content << "You can view this game online at http://modkiwi.no-ip.biz/game/#{gid}"
		end
		content << "[/color]"
		$wi.edit_article(article_id, "Signup List", content);
		$conn.query("UPDATE games SET signup_modified = FALSE WHERE gid = #{gid}")
	end
	res = $conn.query("SELECT id, gid, action FROM actions")
	for row in res
		(id, gid, action) = row
		if (action == "postsignup")
			gres = $conn.query("SELECT thread_id FROM games WHERE gid = #{gid}")
			for grow in gres
				thread = grow[0]
				signup_id = $wi.post(thread, "[color=#008800]To sign up for this game, post [b]signup[/b] in bold.\nYou can also sign up at http://modkiwi.no-ip.biz/game/#{gid}[/color]")
			end
			$conn.query("UPDATE games SET signup_id = #{signup_id} WHERE gid = #{gid}")
			$conn.query("DELETE FROM actions WHERE id = #{id}")
		end
	end
end
