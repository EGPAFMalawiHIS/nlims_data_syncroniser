# frozen_string_literal: true

require 'rest-client'
require 'order_service'

# CouchdbMysqlSynchroniser job
class CouchdbMysqlSynchroniser
  include SuckerPunch::Job
  workers 1

  def perform
    unless File.exist?("#{Rails.root}/tmp/couch_seq_number")
      FileUtils.touch "#{Rails.root}/tmp/couch_seq_number"
      seq = '0'
      File.open("#{Rails.root}/tmp/couch_seq_number", 'w') do |f|
        f.write(seq)
      end
    end

    config = YAML.load_file("#{Rails.root}/config/couchdb.yml") [Rails.env]
    username = config['username']
    password = config['password']
    db_name = config['prefix'].to_s + '_order_' + config['suffix'].to_s
    ip = config['host']
    port = config['port']
    protocol = config['protocol']
    seq = File.read("#{Rails.root}/tmp/couch_seq_number")

    res = JSON.parse(RestClient.get("#{protocol}://#{username}:#{password}@#{ip}:#{port}/#{db_name}/_changes?include_docs=true&limit=3000&since=#{seq}"))
    docs = res['results']
    docs.each do |document|
      puts 'Run in CouchdbMysqlSynchroniser Background Job'
      tracking_number = document['doc']['tracking_number']
      if document['deleted'].blank?
        couch_id = document['doc']['_id']
        if OrderService.check_order(tracking_number) == true
          OrderService.update_order(document, tracking_number)
          puts "updated order #{tracking_number}"
        else
          OrderService.create_order(document, tracking_number, couch_id)
          puts "created order #{tracking_number}"
        end
      end
      File.open("#{Rails.root}/tmp/couch_seq_number", 'w') do |f|
        f.write(document['seq'])
      end
    end

    CouchdbMysqlSynchroniser.perform_in(3000)
  rescue StandardError
    CouchdbMysqlSynchroniser.perform_in(3000)
  end
end
