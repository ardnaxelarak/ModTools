#!/usr/bin/ruby

require_relative 'Bot2r1b'
require_relative 'Scan'
require_relative 'Setup'
require 'yaml'

$wi.verbose = false

END_LINE = "------------------"

puts Time.now.strftime("%d/%m/%Y %H:%M")

res = $conn.query("SELECT gid, g.tid, t.short_name, game_index, g.name FROM games g LEFT JOIN statuses s ON g.status = s.sid LEFT JOIN game_types t ON g.tid = t.tid WHERE s.scan")

begin
	check_mail(true)
	for row in res
		(gid, tid, tsn, gind, name) = row
		gid = gid.to_i
		tid = tid.to_i
		puts "Opening #{tsn} ##{gind}: #{name}"

		if (tid == 1)
			b = Bot2r1b.new(row[0].to_i)
			b.scan(true)
			b.tally(false, nil, false)
			# scan_transfers(b, true)
		end
	end
ensure
	close_connections
	puts END_LINE
end
