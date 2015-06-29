conn = ({:host => '127.0.0.1', :username => 'root', :password => node['mysql']['server_root_password']})

template '/root/.ssh/id_rsa' do
  source 'private.key'
  owner 'root'
  group 'root'
  mode '00600'
  action :create
end

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
  connection conn
  action :create
end

dump = Chef::Config[:file_cache_path] + "/dump.sql"
create_dump = ' mysqldump --skip-lock-tables --single-transaction --flush-logs --hex-blob --master-data=2 -h127.0.0.1 -uroot -p' + node['mysql']['server_root_password'] + ' ' + node['dbrepl']['database']
execute "get_dump"  do
  command "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa root@" + node['dbrepl']['master_host'] + ' "' + create_dump + '" > ' + dump
  action :run
end

execute "load-dump" do
  command "mysql -h127.0.0.1 -uroot -p" + node['mysql']['server_root_password'] + " " + node['dbrepl']['database'] + " < " + dump
  action :run
end

Chef::Resource::RubyBlock.send(:include, Chef::Mixin::ShellOut)
if File.exist?(dump)
  command = "head -n80 " + dump + " | grep MASTER_LOG_FILE | awk '{ print $5 }' | awk -F\\' '{print $2}' | tr -d '\n'"
  mlf = Chef::ShellOut.new(command)
  mlf.run_command
  master_log_file = mlf.stdout
  command = "head -n80 " + dump + " | grep MASTER_LOG_POS | awk '{ print $6 }' | cut -f2 -d '=' | cut -f1 -d';' | tr -d '\n'"
  p = Chef::ShellOut.new(command)
  p.run_command
  position = p.stdout
end

unless master_log_file.nil?
    mysql_database "change_master" do
    connection conn
    sql "CHANGE MASTER TO MASTER_HOST='" + node['dbrepl']['master_host'] + "', MASTER_USER='" + node['dbrepl']['master_user'] + "', MASTER_PASSWORD='" + node['mysql']['server_repl_password'] + "', MASTER_LOG_FILE ='" + master_log_file + "', MASTER_LOG_POS=" + position + ";"
    action :query
  end
end
mysql_database "start_slave" do
  connection conn
  sql "START SLAVE"
  action :query
end

template '/root/check-master.sh' do
  source 'check-master.sh'
  owner 'root'
  group 'root'
  mode '00755'
  variables(
  :master_host => node['dbrepl']['master_host'],
  :repl_user => node['dbrepl']['master_user'],
  :mysql_root_pass => node['mysql']['server_root_password'],
  :mysql_repl_pass => node['mysql']['server_repl_password']
  )
  action :create
end

include_recipe 'cron'
cron 'check-master' do
  command '/root/check-master.sh'
  user    'root'
end
