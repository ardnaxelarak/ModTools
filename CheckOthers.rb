#!/usr/bin/ruby

require_relative 'Updates'

$wi.verbose = false

begin
	check_signups
	check_others
ensure
	close_connections
end
