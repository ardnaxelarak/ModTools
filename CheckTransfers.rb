#!/usr/bin/ruby

require_relative 'ModTools'
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
@@wi = Interface.new(File.expant_path("../default_auth", THIS_FILE))

if (File.exist?(filename))
	m = ModTools.load(filename)
else
	exit
end

begin
	m.update
	scan_transfers(m, @@wi, @@pl, true)
	m.save
ensure
	@@wi.stop
	puts "---------------------------"
end
