#!/usr/bin/env ruby
# encoding: utf-8
require_relative '../environment.rb'
require 'benchmark'

iterations = 100

occ = Bloodhound.find(1124328)

Benchmark.bm do |bm|

  bm.report("agents_orig") do
    iterations.times do
      occ.agents
    end
  end

end