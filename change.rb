 config = YAML.load_file("#{Rails.root}/config/couchdb.yml") [Rails.env]
  site_conf = YAML.load_file("#{Rails.root}/config/application.yml")
  username = config['username']
  password = config['password']
  db_name = config['prefix'].to_s +  "_order_" +  config['suffix'].to_s
  ip = config['host']
  port = config['port']
  protocol = config['protocol']
  seq = File.read("#{Rails.root}/tmp/couch_seq_number")
  seq = seq.to_i - 1
  res = JSON.parse(RestClient.get("#{protocol}://#{username}:#{password}@#{ip}:#{port}/#{db_name}/_changes"))

#raise res.inspect
 File.open("#{Rails.root}/change_number",'w'){ |f|
      f.write(res)
     }
raise res.inspect
puts "am done"
