namespace :pocogese do

desc "Generates ActionScript classes with Command and Selection API methods for ActionControllers"
task :generate  => :environment do
  require 'lib/generators/flex_generator'  
  require 'application'
  
  rails_project_root File.expand_path(__FILE__+'/../..')
  flex_project_root 'C:\dev\radrace2007\rtunes-flex'
  flex_package_root 'com.philemonworks.rtunes'

  # Generates a client, interface in Flex that can access the action controller
  #
  flex_controller_from :TrackController

end

end # namespace