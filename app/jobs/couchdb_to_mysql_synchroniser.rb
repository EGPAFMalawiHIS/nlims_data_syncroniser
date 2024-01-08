# frozen_string_literal: true

require 'rest-client'
require 'order_service'
require 'couch_to_mysql_service'

# CouchdbMysqlSynchroniser job
class CouchdbMysqlSynchroniser
  include SuckerPunch::Job
  workers 1

  def perform
    CouchToMysqlService.sync
    CouchdbMysqlSynchroniser.perform_in(3000)
  rescue StandardError
    CouchdbMysqlSynchroniser.perform_in(3000)
  end
end
