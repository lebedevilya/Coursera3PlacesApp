require 'exifr/jpeg'

class Photo
  attr_accessor :id, :location
  attr_writer :contents

  def self.mongo_client
    Mongoid::Clients.default
  end

  def initialize(params=nil)
  	if params.nil?
  		@id = nil
  		@location = nil
      @place = nil
  	else
  		@id = params[:_id].to_s if params[:_id]
  		@location = Point.new(params[:metadata][:location]) if params[:metadata][:location]
      @place = params[:metadata][:place] if params[:metadata][:location]
  	end
  end

  def place
    Place.find(@place) if @place.is_a? BSON::ObjectId
  end

  def place=(object)
    case
    when object.is_a?(Place)
      @place=BSON::ObjectId.from_string(object.id)
    when object.is_a?(String)
      @place=BSON::ObjectId.from_string(object)
    when object.is_a?(BSON::ObjectId)
      @place=object
    end
  end  

  def persisted?
    !@id.nil?
  end

  def save
  	if persisted?
      self.class.mongo_client.database.fs.find(_id: BSON::ObjectId.from_string(@id)).update_one('$set' => {"metadata.location" => @location.to_hash, "metadata.place" => @place})
    else 
  		gps = EXIFR::JPEG.new(@contents).gps
  		@location = Point.new(:lng => gps.longitude, :lat => gps.latitude)
  		@contents.rewind
  		options = {}
      options[:metadata] = {}
		  options[:metadata][:location] = @location.to_hash
      options[:metadata][:place] = @place if @place.is_a? Place
		  options[:content_type] = "image/jpeg"
  		grid_file = Mongo::Grid::File.new(@contents.read, options)
  		r = self.class.mongo_client.database.fs.insert_one(grid_file)
  		@id = r.to_s
  	end
  end

  def self.all(offset=0, limit=nil)
  	result = self.mongo_client.database.fs.find.skip(offset)
  	result = result.limit(limit) if limit
  	ans = []
  	result.map {|doc| ans << Photo.new(doc)}
  	return ans
  end

  def self.find(id)
    result = self.mongo_client.database.fs.find(_id: BSON::ObjectId.from_string(id)).first
    unless result.nil?
      photo = Photo.new()
      photo.location = Point.new(
        lng: result[:metadata][:location][:coordinates][0],
        lat: result[:metadata][:location][:coordinates][1])
      photo.id = result[:_id].to_s
      photo.place = BSON::ObjectId.from_string(result[:metadata][:place]) if result[:metadata][:place]
      photo
    end
  end

  def contents
    stored_file = self.class.mongo_client.database.fs.find_one(_id: BSON::ObjectId.from_string(@id))
    ans = "";
    stored_file.chunks.reduce([]) { |x, chunk| ans << chunk.data.data}
    ans
  end

  def destroy
    self.class.mongo_client.database.fs.find(_id: BSON::ObjectId.from_string(@id)).delete_one
  end

  def find_nearest_place_id(max_distance)
    nearest_place = Place.near(@location, max_distance)
    nearest_place.nil? ? nil : nearest_place.first[:_id]
  end

  def self.find_photos_for_place(place_id)
    place_id = BSON::ObjectId.from_string(place_id.to_s)
    result = self.mongo_client.database.fs.find('metadata.place' => place_id)
  end
end