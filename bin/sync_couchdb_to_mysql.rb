 require "order_service.rb"
 
 if !File.exists?("#{Rails.root}/tmp/couch_seq_number")
    FileUtils.touch "#{Rails.root}/tmp/couch_seq_number"
    seq = "0"
    File.open("#{Rails.root}/tmp/couch_seq_number",'w'){ |f|
      f.write(seq)
    }
  end

  config = YAML.load_file("#{Rails.root}/config/couchdb.yml") [Rails.env]
  username = config['username']
  password = config['password']
  db_name = config['prefix'].to_s +  "_order_" +  config['suffix'].to_s
  ip = config['host']
  port = config['port']
  protocol = config['protocol']
 
if !File.exists?("#{Rails.root}/log/couch_mysql_sync.lock")

  FileUtils.touch "#{Rails.root}/log/couch_mysql_sync.lock"

  seq = File.read("#{Rails.root}/tmp/couch_seq_number")
  res = JSON.parse(RestClient.get("#{protocol}://#{username}:#{password}@#{ip}:#{port}/#{db_name}/_changes?include_docs=true&limit=3000&since=#{seq}"))
  docs = res['results']
  
  docs.each do |document|
    tracking_number = document['doc']['tracking_number']
   # puts tracking_number
    document['doc']['order_location'] = "Queens Elizabeth Central Hospital" if document['doc']['order_location'] == "Queen Elizabeth Central Hospital"
   
    #next if tracking_number.include?("XLLH")
    next if !document['deleted'].blank?
    next if document['doc']['tracking_number'][1..3] == "KCH" 
    next if document['doc']['tracking_number'][1..3] == "MCH" 
    next if document['doc']['tracking_number'][1..3] == "QCH" 
    next if document['doc']['tracking_number'][1..3] == "ZCH" 
    next if document['doc']['tracking_number'][1..3] == "MZD" 
    next if document['doc']['tracking_number'][1..3] == "TDH"
    next if document['doc']['tracking_number'][1..3] == "NDH"
    next if document['doc']['tracking_number'][1..4] == "CHSU"
    puts tracking_number

    couch_id =  document['doc']['_id']
    if OrderService.check_order(tracking_number) == true                 
        #if OrderService.check_data_anomalies(document) == true    
        #   OrderService.update_order(document,tracking_number)
        #end
	puts "arleady in, sorry"
    else                
        #if OrderService.check_data_anomalies(document) == true
  	   puts "checking am in------------"
	   puts document
	   puts document['art_start_date']
           puts "-----============" 
	   OrderService.create_order(document,tracking_number,couch_id)
	#end         
    end
     File.open("#{Rails.root}/tmp/couch_seq_number",'w'){ |f|
      f.write(document['seq'])
     } 
 end
	File.delete("#{Rails.root}/log/couch_mysql_sync.lock")

else
  puts "another syncing job running currently--------------"
end
