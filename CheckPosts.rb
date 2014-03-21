#!/usr/bin/ruby

require_relative 'ModTools'
require 'yaml'

unless ARGV.length > 0
	puts "Usage: CheckPosts.rb <filename>"
	exit
else
	filename = ARGV.shift
end

THIS_FILE = File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__

@@pl = PlayerList.new(File.expand_path("../players", THIS_FILE))
@@wi = Interface.new

if (File.exist?(filename))
	m = ModTools.load(filename)
else
	exit
end

begin
	m.update
	m.scan
	m.tally
	m.save
ensure
	@@wi.stop
end
