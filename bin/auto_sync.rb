settings = YAML.load_file("#{Rails.root}/config/application.yml")
couchdb_settings = YAML.load_file("#{Rails.root}/config/couchdb.yml")[Rails.env]
site_name = settings['site_name']
site_code = settings['site_code']

ip = couchdb_settings['host']
port = couchdb_settings['port']
username = couchdb_settings['username']
password = couchdb_settings['password']

def add_site(district,name,x,y,region,description,enabled,sync_status,site_code,application_port,host_address,couch_username,couch_password)
    res = Site.create(
            :district => district,
            :name => name,
            :x => x,
            :y => y,
            :region => region,
            :description => description,
            :enabled => enabled,
            :sync_status => sync_status,
            :site_code => site_code,
            :application_port => application_port,
            :host_address => host_address,
            :couch_username => couch_username,
            :couch_password => couch_password
         )            
    return res
end



site = Site.find_by_sql("select id from sites where name='#{site_name}'")
if !site.blank?
    site = site[0].id
else
    district =  settings['district']
    name = settings['site_name']
    x = "1.11"
    y = "0.012"
    region = settings['region']
    description = ""
    enabled = false
    sync_status = false
    site_code = settings['site_code']
    application_port = couchdb_settings['port']
    host_address = couchdb_settings['host']
    couch_username = couchdb_settings['username']
    couch_password = couchdb_settings['password']

    site = add_site(district,name,x,y,region,description,enabled,sync_status,site_code,application_port,host_address,couch_username,couch_password)  
end

puts "setting up data source"

    res = Site.where(id: site).update_all(application_port: port, host_address: ip, enabled: true, site_code: site_code,couch_username: username, couch_password: password)
    if res == 1
       puts "data source saved"
    end

puts "finished setting up data source, now setting up data destination"

site_name = "Community Health Sciences Unit (CHSU)"
site_code = "CHSU"

<<<<<<< HEAD
ip = "10.44.0.4"
=======

ip = "10.44.0.46"
>>>>>>> f390d8b
port = "5984"
username = "admin"
password = "root"


site = Site.find_by_sql("select id from sites where name='#{site_name}'")
if !site.blank?
    site = site[0].id
else
    district =  "Lilogwe"
    name = site_name
    x = "35.7899"
    y = "-16.8933"
    region = "Central"
    description = ""
    enabled = false
    sync_status = false
    site_code = site_code
    application_port = port
    host_address = ip
    couch_username = username
    couch_password = password

    site = add_site(district,name,x,y,region,description,enabled,sync_status,site_code,application_port,host_address,couch_username,couch_password)  
end

    res = Site.where(id: site).update_all(application_port: port, host_address: ip, enabled: true, site_code: site_code,couch_username: username, couch_password: password)
    if res == 1
    puts "data destination saved"
    end

puts "finished setting up data destination"


