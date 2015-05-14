require 'mongrel_cluster/recipes'
require 'lib/tasks/local_subversion_rsync.rb'

# Vul hier uw domeinnaam in als gebruikersnaam (:user)
# en de server zoals deze in uw email stond als
# applicatienaam (:application) in waarop de applicatie komt te draaien

set :user, "rtunes.philemonworks.com"
set :application, "s009867.railsnet.nl"
# Vul hier de locatie in van uw SVN repository
# waar de code van het project staat
# (alleen indien van toepassing).
set :repository, "url_van_uw_svn"

# Byte Defaults, should work!

set :deploy_to, "~"
set :use_sudo, false

set :scm, Capistrano::SCM::LocalSubversionRsync
set :repository_is_not_reachable_from_remote, true

# Byte manages the location of your mongrel instances, so
# the only machine here is the deployment system. Do NOT change
# for example the :db role to the database system you use
# in your config/database.yml

role :web, application
role :app, application
role :db,  application, :primary => true

# Byte Tasks, don't edit these unless you know what you are doing!

# Fix permissions for the log file if it exists
task :set_permissions, :except => { :no_release => true } do
  run "([ -f #{deploy_to}/revisions.log ] \
        && chmod 600 #{deploy_to}/revisions.log) || true"
end

# Use the Byte mongrel manager. You cannot start your Mongrels using
# the standard Mongrel recipes, so don't remove this task!
task :restart, :roles => [:app] do
  sudo "mongrel_manager restart", :as => "manager"
end

# Task for setup of the new version after a manual upload. This is useful
# for people deploying from Windows who don't have tar / ssh / scp / svn
# available. The procedure is to first upload the new version to ~/new
# and after that to run this task. This will copy the ~/new directory
# to the timestamp format in ~/releases, fix permissions for Apache,
# update the log symlink, update the current symlink and restart the
# mongrel processes.
task :deploy_uploaded do
  stamp = Time.now.strftime("%Y%m%d%H%M%S")
  run "cp -r ~/new #{releases_path}/#{stamp}"
  run <<-CMD
    rm -rf #{current_release}/log #{current_release}/public/system &&
    ln -nfs #{shared_path}/log #{current_release}/log &&
    ln -nfs #{shared_path}/system #{current_release}/public/system
  CMD

  set_permissions
  symlink
  restart
end