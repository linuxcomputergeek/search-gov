set :user,        "search"
set :deploy_to,   "/home/jwynne/#{application}"
set :domain,      "192.168.100.160"
server domain, :app, :web, :db, :primary => true
