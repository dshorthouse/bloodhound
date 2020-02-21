# encoding: utf-8

module Bloodhound
  class FrictionlessDataAsync
    include SuckerPunch::Job

    def perform(data)
      fd = FrictionlessData.new(data)
      fd.create_package
    end

  end
end
