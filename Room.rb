require_relative "Player"
require_relative "Vote"
require_relative "Setup"

class Room
	attr_accessor :rid, :name, :thread
	def initialize(rid)
		@rid = rid
		res = $conn.query("SELECT name, thread_id FROM rooms WHERE rid = #{@rid}")
		return unless row = res.fetch_row
		(@name, @thread) = row
	end

	def players
		pl = []
		res = $conn.query("SELECT pid FROM room_players WHERE rid = #{@rid}")
		for row in res
			pl.push(row[0].to_i)
		end
		return pl
	end

	def offer_player(pid1, pid2)
		# @offered_to[pid1] = pid2 unless @accepted[pid1]
	end

	def set_weight(pid, weight)
		$conn.query("UPDATE room_players SET weight = #{weight} WHERE rid = #{@rid} AND pid = #{pid}")
	end

	def last_article
		return nil unless row = $conn.query("SELECT last_scanned FROM rooms WHERE rid = #{@rid}").fetch_row
		return row[0]
	end

	def last_article=(value)
		$conn.query("UPDATE rooms SET last_scanned = #{value} WHERE rid = #{@rid}")
	end

	def accept_offer(pid2, pid1)
		# return nil unless @offered_to[pid1] == pid2
		# @offered_to[pid1] = nil
		# if @leader == pid1
		#	update_leader(pid2)
		# else
		#	@accepted[pid1] = pid2
		# end
		# return true
	end

	def revoke_offer(pid1)
		# @offered_to[pid1] = nil
		# @accepted[pid1] = nil
	end

	def total_votes
		res = $conn.query("SELECT total FROM total_votes WHERE rid = #{@rid}")
		return nil unless row = res.fetch_row
		return nil unless row[0]
		return row[0].to_f
	end

	def clear_votes
		$conn.query("DELETE FROM room_votes WHERE rid = #{@rid}")
	end

	def add_player(pid)
		return if contain?(pid)
		$conn.query("INSERT INTO room_players (rid, pid) VALUES (#{@rid}, #{pid})")
		$conn.query("INSERT INTO room_messages (rid, message) VALUES (#{@rid}, '#{$pl[pid].name} has joined the room.')")
		$conn.query("UPDATE rooms SET modified = 1 WHERE rid = #{@rid}")
	end

	def remove_player(pid)
		return unless contain?(pid)
		$conn.query("DELETE FROM room_players WHERE rid = #{@rid} AND pid = #{pid}")
		$conn.query("INSERT INTO room_messages (rid, message) VALUES (#{@rid}, '#{$pl[pid].name} has left the room.')")
		$conn.query("UPDATE rooms SET modified = 1 WHERE rid = #{@rid}")
		recalc
	end

	def contain?(pid)
		res = $conn.query("SELECT pid FROM room_players WHERE pid = #{pid} AND rid = #{@rid}")
		return res.num_rows > 0
	end

	def need_tally?
		res = $conn.query("SELECT modified FROM rooms WHERE rid = #{@rid}")
		return false unless row = res.fetch_row
		return row[0].to_i > 0
	end

	def leader_name
		res = $conn.query("SELECT leader FROM rooms WHERE rid = #{@rid}")
		return "None" unless row = res.fetch_row
		return "None" unless row[0]
		return $pl[row[0].to_i].name
	end

	def tally(update = false, hidden = false)
		text = ""
		text = "[o]" if hidden
		res = $conn.query("SELECT message FROM room_messages WHERE rid = #{@rid} ORDER BY mid")
		if res.num_rows > 0
			text << "[b][color=purple]"
			for row in res
				text << "#{row[0]}\n"
			end
			text << "[/b][/color]\n"
		end
		text << "[color=#009900]Current Leader: #{leader_name}"
		text << "\n\nVOTE TALLY:"
		
		res = $conn.query("SELECT pid, votes FROM vote_tally WHERE rid = #{@rid} ORDER BY votes DESC, last, last_old")
		for row in res
			pid = row[0].to_i
			vs = $conn.query("SELECT VoteString(#{@rid}, #{pid})")
			next unless vs = vs.fetch_row
			text << "\n#{vs[0]}"
		end

		nv = []
		res = $conn.query("SELECT pid FROM not_voted WHERE rid = #{@rid}")
		for row in res
			nv.push(row[0].to_i)
		end
		nv = nv.collect{|pid| $pl[pid].name}.sort_by{|name| name.upcase}
		text << "\n\nNot voting: #{nv.join(", ")}" if nv.length > 0
		text << "\n\n'*' indicates a locked vote."

		text << "[/color]"
		if update
			$conn.query("UPDATE rooms SET modified = FALSE WHERE rid = #{@rid}")
			$conn.query("DELETE FROM room_messages WHERE rid = #{@rid}")
		end
		text << "[/o]" if hidden
		return text
	end

	def choose_leader
		res = $conn.query("SELECT pid FROM vote_tally WHERE rid = #{@rid} ORDER BY votes DESC, last LIMIT 1")
		return nil unless row = res.fetch_row
		update_leader(row[0].to_i)
		return row[0].to_i
	end

	def vote(voter, votee, locked = false)
		$conn.query("INSERT INTO room_votes (rid, voter, votee, locked) VALUES (#{@rid}, #{voter}, #{votee}, #{locked ? "1" : "0"})")
		$conn.query("UPDATE rooms SET modified = TRUE WHERE rid = #{@rid}")
		recalc
	end

	def recalc
		res = $conn.query("SELECT v.pid, r.leader FROM vote_tally v JOIN rooms r ON v.rid = r.rid WHERE v.rid = #{@rid} AND votes > (SELECT count(*) FROM room_players rp WHERE rp.rid = #{@rid}) / 2 ORDER BY votes DESC, last")
		return unless row = res.fetch_row
		oldleader = row[1]
		oldleader = oldleader.to_i if oldleader
		leader = row[0].to_i
		
		update_leader(leader) unless leader == oldleader
	end

	def add_transfer(sender, sent)
		# @to_send[sender] = [] unless @to_send[sender]
		# @to_send[sender].push(sent)
	end

	def get_transfer
		# return nil unless @leader
		# return nil unless @to_send[@leader]
		# return @to_send[@leader].last
	end

	def update_leader(newleader)
		$conn.query("UPDATE rooms SET leader = #{newleader}, modified = TRUE WHERE rid = #{@rid}")
		$conn.query("INSERT INTO room_messages (rid, message) VALUES (#{@rid}, '#{$pl[newleader].name} has become leader!')")
		# @leader = @accepted[newleader] if @accepted[newleader]
	end

	def lock(votee)
		# @locked[votee] = true
		# @changes = true
	end

	def unlock(votee)
		# @locked[votee] = false
		# @changes = true
	end
end
