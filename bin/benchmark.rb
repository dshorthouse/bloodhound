#!/usr/bin/env ruby
# encoding: utf-8
require_relative '../environment.rb'
require 'benchmark'

namestring = "Smith, William Leo; Bentley, Andrew C; Girard, Matthew G; Davis, Matthew P; Ho, Hsuan-Ching"

iterations = 3500

Benchmark.bm do |bm|

  bm.report("custom_parse") do
    iterations.times do
      names = []
      DwcAgent.parse(namestring).each do |r|
        name = DwcAgent.clean(r)
        if !name[:family].nil? && name[:family].length >= 3
          names << name
        end
      end
      names.uniq
    end
  end

  bm.report("namae_parse") do
    iterations.times do
      Namae.parse(namestring)
    end
  end

end