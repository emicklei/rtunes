class CreateTracks < ActiveRecord::Migration
  def self.up
    create_table :tracks do |table|
      table.column 'itunes_track_id' , :integer
      table.column 'name' , :string , :limit => 100
      table.column 'artist' , :string , :limit => 100
      table.column 'album' , :string , :limit => 100
      table.column 'genre' , :string , :limit => 100
      table.column 'duration' , :integer  
      
      #assocs
      table.column 'useraccount_id' , :integer
    end
  end

  def self.down
    drop_table :tracks
  end
end
