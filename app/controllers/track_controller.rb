class TrackController < ApplicationController
  layout "admin"
  active_scaffold :track
  pocogese :track
  
  selection_api :find_all_genres
  def find_all_genres
    self.find_distinct(:genre)    
  end
  
  selection_api :find_all_artists
  def find_all_artists
    self.find_distinct(:artist)    
  end
  
  selection_api :find_all_albums
  def find_all_albums
    self.find_distinct(:album)    
  end
  
  selection_api :find_all_by_genre , :genre
  def find_all_by_genre(genre)
    self.find_all_where('genre', genre)
  end
  
  selection_api :find_all_by_artist , :artist  
  def find_all_by_artist(artist)
    self.find_all_where('artist', artist)
  end
  
  selection_api :find_all_by_album , :album
  def find_all_by_album(album)
    self.find_all_where('album', album)
  end 

  
  ###################################################################
  
  protected
  
  def find_distinct(column_sym)
    tracks = Track.find_by_sql "SELECT distinct(#{column_sym}) FROM tracks"
    StringCollection.new(tracks.collect(&column_sym),column_sym.to_s)
  end
  
  def find_all_where(column,value)
    Track.find(:all, :conditions =>[ "#{column} = ?" , value])
  end 
  
end
