# frozen_string_literal: true

require 'couch_to_couch_service'
require 'rest-client'

# CouchSync service
class CouchSync
  include SuckerPunch::Job
  workers 1

  def perform
    CouchToCouchService.sync
    CouchSync.perform_in(2000)
  rescue StandardError
    CouchSync.perform_in(2000)
  end
end
