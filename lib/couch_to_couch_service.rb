# frozen_string_literal: true

# couch to couch sync module
module CouchToCouchService
  def self.sync(run_file = 'CouchSync Background Job')
    puts "Run in #{run_file}"
    couchdb_config = YAML.load_file("#{Rails.root}/config/couchdb.yml")
    remote_couchdb = couchdb_config['chsu_couch_db']
    local_couchdb = couchdb_config[Rails.env]
    db_name = "#{local_couchdb['prefix']}_order_#{local_couchdb['suffix']}"
    local_address = "http://#{local_couchdb['username']}:#{local_couchdb['password']}@#{local_couchdb['host']}:#{local_couchdb['port']}/#{db_name}"
    remote_address = "http://#{remote_couchdb['username']}:#{remote_couchdb['password']}@#{remote_couchdb['ip']}:#{remote_couchdb['port']}/#{db_name}"

    `curl -X POST http://#{local_couchdb['host']}:#{local_couchdb['port']}/_replicate -d '{"source":"#{local_address}","target":"#{remote_address}","create_target":  true, "continuous":true}' -H "Content-Type: application/json"`
    `curl -X POST http://#{remote_couchdb['ip']}:#{remote_couchdb['port']}/_replicate -d '{"source":"#{remote_address}","target":"#{local_address}","create_target":  true, "continuous":true}' -H "Content-Type: application/json"`
  end
end
