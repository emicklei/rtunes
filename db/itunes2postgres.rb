 #!/usr/bin/ruby
  
 require 'active_record'
 
 ActiveRecord::Base.establish_connection(
   :adapter  => "postgresql",
   :host     => "localhost",
   :username => "ernest",
   :password => "micklei",
   :database => "rtunes_development"
 )

class Track < ActiveRecord::Base
end

require 'win32ole'

iTunes = WIN32OLE.new('iTunes.Application')
tracks = iTunes.LibraryPlaylist.Tracks

tracks.each { |each|
	track = Track.new
	%w{Name Artist Album Genre Duration}.each do | field |
		track[field.downcase]=each.send field
	end
	
	begin
		track.save
		puts "Saved: #{track.name}"
	rescue ActiveRecord::StatementInvalid
		puts "Unable to save track because #{$!}"
	end
	
}
puts "done"
 
 