include_recipe "dbrepl::slave-prepare"
mysql_database "start slave" do
  connection ({:host => '127.0.0.1', :username => 'root', :password => node['mysql']['server_root_password']})
  sql "CHANGE MASTER TO MASTER_HOST='" + node['dbrepl']['master_host'] + "', MASTER_USER='" + node['dbrepl']['master_user'] + "', MASTER_PASSWORD='" + node['mysql']['server_repl_password'] + "', MASTER_LOG_FILE ='" + ::File.open(master_log_file).read + "', MASTER_LOG_POS=" + ::File.open(position).read + ";"
  action :query
end
