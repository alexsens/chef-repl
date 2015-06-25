#include_recipe "users"

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
  source 'replication-slave.erb'
  variables(server_id: '2', mysql_instance: 'master', database: node['dbrepl']['database'])
  notifies :restart, 'mysql_service[master]', :immediately
  action :create
end

mysql_database node['dbrepl']['database'] do
  connection ({:host => '127.0.0.1', :username => 'root', :password => node['mysql']['server_root_password']})
  action :create
end

dump = Chef::Config[:file_cache_path] + "/dump.sql"
create_dump = ' mysqldump --skip-lock-tables --single-transaction --flush-logs --hex-blob --master-data=2 -h127.0.0.1 -uroot -p' + node['mysql']['server_root_password'] + ' ' + node['dbrepl']['database']
execute "get_dump"  do
  command "ssh root@" + node['dbrepl']['master_host'] + ' "' + create_dump + '" > ' + dump
  action :run
end

#position = Chef::Config[:file_cache_path] + "/position"
#execute "get_position" do
#  command "head -n80 " + dump + " | grep MASTER_LOG_POS | awk '{ print $6 }' | cut -f2 -d '=' | cut -f1 -d';' | tr -d '\n' > " + position
#  action :run
#end
#f = File.open(position)
#position = f.read
#f.close
Chef::Resource::RubyBlock.send(:include, Chef::Mixin::ShellOut)
#ruby_block "qwe" do
#block do
#  command = "head -n80 " + dump + " | grep MASTER_LOG_POS | awk '{ print $6 }' | cut -f2 -d '=' | cut -f1 -d';' | tr -d '\n'"
#  position = shell_out(command)
#end
#end 
#master_log_file = Chef::Config[:file_cache_path] + "/master_log_file"
#execute "get_master_log_file" do
#  command "head -n80 " + dump + " | grep MASTER_LOG_FILE | awk '{ print $5 }' | awk -F\\' '{print $2}' | tr -d '\n' > " + master_log_file
#  action :run
#end
#f = File.open(master_log_file)
#master_log_file = f.read
#f.close
command = "head -n80 " + dump + " | grep MASTER_LOG_FILE | awk '{ print $5 }' | awk -F\\' '{print $2}' | tr -d '\n'"
mlf = Chef::ShellOut.new(command)
mlf.run_command
master_log_file = mlf.stdout

command = "head -n80 " + dump + " | grep MASTER_LOG_POS | awk '{ print $6 }' | cut -f2 -d '=' | cut -f1 -d';' | tr -d '\n'"
p = Chef::ShellOut.new(command)
p.run_command
position = p.stdout

execute "load-dump" do
  command "mysql -h127.0.0.1 -uroot -p" + node['mysql']['server_root_password'] + " " + node['dbrepl']['database'] + " < " + dump
  action :run
end

mysql_database "start slave" do
  connection ({:host => '127.0.0.1', :username => 'root', :password => node['mysql']['server_root_password']})
  sql "CHANGE MASTER TO MASTER_HOST='" + node['dbrepl']['master_host'] + "', MASTER_USER='" + node['dbrepl']['master_user'] + "', MASTER_PASSWORD='" + node['mysql']['server_repl_password'] + "', MASTER_LOG_FILE ='" + master_log_file + "', MASTER_LOG_POS=" + position + ";"
  sql "START SLAVE"
  action :query
end
