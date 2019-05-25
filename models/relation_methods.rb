# frozen_string_literal: true
# Taken from AR 6
# https://github.com/rails/rails/blob/6-0-stable/activerecord/lib/active_record/relation.rb

module Sinatra
  module Bloodhound
    module RelationMethods
      extend ActiveSupport::Concern

      class_methods do
        # Attempts to create a record with the given attributes in a table that has a unique constraint
        # on one or several of its columns. If a row already exists with one or several of these
        # unique constraints, the exception such an insertion would normally raise is caught,
        # and the existing record with those attributes is found using #find_by!.
        #
        # This is similar to #find_or_create_by, but avoids the problem of stale reads between the SELECT
        # and the INSERT, as that method needs to first query the table, then attempt to insert a row
        # if none is found.
        #
        # There are several drawbacks to #create_or_find_by, though:
        #
        # * The underlying table must have the relevant columns defined with unique constraints.
        # * A unique constraint violation may be triggered by only one, or at least less than all,
        #   of the given attributes. This means that the subsequent #find_by! may fail to find a
        #   matching record, which will then raise an <tt>ActiveRecord::RecordNotFound</tt> exception,
        #   rather than a record with the given attributes.
        # * While we avoid the race condition between SELECT -> INSERT from #find_or_create_by,
        #   we actually have another race condition between INSERT -> SELECT, which can be triggered
        #   if a DELETE between those two statements is run by another client. But for most applications,
        #   that's a significantly less likely condition to hit.
        # * It relies on exception handling to handle control flow, which may be marginally slower.
        # * The primary key may auto-increment on each create, even if it fails. This can accelerate
        #   the problem of running out of integers, if the underlying table is still stuck on a primary
        #   key of type int (note: All Rails apps since 5.1+ have defaulted to bigint, which is not liable
        #   to this problem).
        #
        # This method will return a record if all given attributes are covered by unique constraints
        # (unless the INSERT -> DELETE -> SELECT race condition is triggered), but if creation was attempted
        # and failed due to validation errors it won't be persisted, you get what #create returns in
        # such situation.
        def create_or_find_by(attributes, &block)
          transaction(requires_new: true) { create(attributes, &block) }
        rescue ActiveRecord::RecordNotUnique
          find_by!(attributes)
        end

        # Like #create_or_find_by, but calls
        # {create!}[rdoc-ref:Persistence::ClassMethods#create!] so an exception
        # is raised if the created record is invalid.
        def create_or_find_by!(attributes, &block)
          transaction(requires_new: true) { create!(attributes, &block) }
        rescue ActiveRecord::RecordNotUnique
          find_by!(attributes)
        end

      end
    end
  end
end