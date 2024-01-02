# frozen_string_literal: true

# CouchToMysqlService syncs couchdb data to mysql
module CouchToMysqlService
  def self.sync(run_file = 'CouchdbMysqlSynchroniser Backgroung Job')
    couch_seq_file_name = "#{Rails.root}/tmp/couch_seq_number"
    create_couch_seq_file(couch_seq_file_name)
    config = YAML.load_file("#{Rails.root}/config/couchdb.yml") [Rails.env]
    username = config['username']
    password = config['password']
    db_name = config['prefix'].to_s + '_order_' + config['suffix'].to_s
    ip = config['host']
    port = config['port']
    protocol = config['protocol']
    seq = File.read(couch_seq_file_name)
    res = JSON.parse(RestClient.get("#{protocol}://#{username}:#{password}@#{ip}:#{port}/#{db_name}/_changes?include_docs=true&limit=3000&since=#{seq}"))
    docs = res['results']
    docs.each do |document|
      puts "Run in #{run_file}"
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
      write_to_couch_seq_file(couch_seq_file_name, seq)
    end
  end

  def self.create_couch_seq_file(file_name)
    return if File.exist?(file_name)

    FileUtils.touch file_name
    seq = '0'
    write_to_couch_seq_file(file_name, seq)
  end

  def self.write_to_couch_seq_file(file_name, seq)
    File.open(file_name, 'w') do |f|
      f.write(seq)
    end
  end
end
