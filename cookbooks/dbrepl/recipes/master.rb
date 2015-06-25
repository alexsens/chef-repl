mysql2_chef_gem 'default' do
  action :install
end

mysql_service 'master' do
  port '3306'
  initial_root_password node['mysql']['server_root_password']
  action [:create, :start]
end

mysql_config 'master replication' do
  config_name 'replication'
  instance 'master'
  source 'replication-master.erb'
  variables(server_id: '1', mysql_instance: 'master', database: node['dbrepl']['database'])
  notifies :restart, 'mysql_service[master]', :immediately
  action :create
end

mysql_database node['dbrepl']['database'] do
  connection ({:host => '127.0.0.1', :username => 'root', :password => node['mysql']['server_root_password']})
  action :create
end
mysql_database 'grant_repl' do
  connection ({:host => '127.0.0.1', :username => 'root', :password => node['mysql']['server_root_password']})
  sql "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%' IDENTIFIED BY '" + node['mysql']['server_repl_password']+ "' ;"
  sql "FLUSH PRIVILEGES;"
  action :query
end

sample_db = Chef::Config[:file_cache_path] + "/sampledb.sql"

remote_file sample_db do
  source "http://pastebin.com/raw.php?i=7t3M3b1y"
  mode "0644"
end

execute "load-dump" do
  command "mysql -h127.0.0.1 -uroot -p" + node['mysql']['server_root_password'] + " " + node['dbrepl']['database'] + " < " + sample_db
end
