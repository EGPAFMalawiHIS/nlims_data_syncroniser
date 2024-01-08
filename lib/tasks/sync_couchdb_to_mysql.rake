# frozen_string_literal: true

namespace :nlims do
  desc 'sync couchdb data to mysql'
  task sync_from_couchdb_to_mysql: :environment do
    CouchToMysqlService.sync('sync_from_couchdb_to_mysql Rake Task')
  end

  desc 'Sync couchdb to couchdb'
  task sync_from_couchdb_to_couchdb: :environment do
    CouchToCouchService.sync('sync_from_couchdb_to_couchdb Rake Task')
  end
end
