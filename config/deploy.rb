# config valid only for current version of Capistrano
lock '3.4.0'
set(:connection_timeout, 5)
set :application, "app"
set :repo_url, "git@github.com:kirs/capistrano-fault-tolerant.git"
set :failure_tolerance, 0.3

# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
# set :deploy_to, '/var/www/my_app_name'
set :deploy_to, '/home/vagrant/app'

# Default value for :scm is :git
# set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
# set :linked_files, fetch(:linked_files, []).push('config/database.yml', 'config/secrets.yml')

# Default value for linked_dirs is []
# set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'vendor/bundle', 'public/system')

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

task :run_script do
  # on roles(:web), in: :parallel_fault_tolerant do
  on roles(:web) do
    # Here we can do anything such as:
    within release_path do
      execute "./script"
    end
  end
end
namespace :deploy do
  after :updated, "run_script"
end
