#!/usr/bin/ruby

require_relative 'Bot2r1b'
require_relative 'ScanTransfers'
require 'yaml'

unless ARGV.length > 0
	puts "Usage: CheckTransfers.rb <filename>"
	exit
else
	filename = ARGV.shift
end

THIS_FILE = File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__

@@pl = PlayerList.new(File.expand_path("../players", THIS_FILE))
@@wi = Interface.new(File.expand_path("../default_auth", THIS_FILE))

if (File.exist?(filename))
	b = Bot2r1b.load(filename)
else
	exit
end

begin
	b.update
	scan_transfers(b, @@wi, @@pl, true)
	b.save
ensure
	@@wi.stop
	puts "---------------------------"
end
