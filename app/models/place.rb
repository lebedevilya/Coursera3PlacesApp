class Place < ActionController::Base
  include ActiveModel::Model

  attr_accessor :id, :formatted_address, :location, :address_components
  
  def self.mongo_client
    Mongoid::Clients.default
  end

  def initialize(params)
  	@id = params[:_id].to_s
  	@formatted_address = params[:formatted_address] if params[:formatted_address]
  	@location = Point.new(params[:geometry][:geolocation]) if params[:geometry][:geolocation]
  	@address_components = []
    if params[:address_components]
  	  params[:address_components]. each do |address|
  		  @address_components << AddressComponent.new(address)
  	  end
    end
  end

  def destroy
    id = BSON::ObjectId.from_string(@id)
    Place.collection.find(:_id => id).delete_one()
  end

  def self.collection
    mongo_client['places']
  end

  def self.load_all(f)
  	places=JSON.parse(f.read)
  	collection.insert_many(places)
  end

  def self.find_by_short_name(short_name)
    collection.find({'address_components.short_name' => short_name})
  end

  def self.to_places(collection)
    places = []
    collection.each do |item|
      places << Place.new(item)
    end
    return places
  end

  def self.find(id)
    id = BSON::ObjectId.from_string(id)
    result = collection.find({:_id => id}).first
    return result.nil? ? nil : Place.new(result)
  end

  def self.all(offset = 0, limit = nil)
    result = collection.find.skip(offset)
    result = result.limit(limit) if limit
    ans = []
    result.each {|p| ans << Place.new(p)}
    return ans
  end

  def self.get_address_components(sort=nil, offset=0, limit=0)
      aggregate_array = [{'$unwind': '$address_components'}, {'$project': {'address_components': 1, 'formatted_address': 1, 'geometry.geolocation': 1}}]
      aggregate_array << {'$sort': sort} if sort
      aggregate_array << {'$skip': offset} if offset > 0
      aggregate_array << {'$limit': limit} if limit > 0
      collection.find.aggregate(aggregate_array)
  end

  def self.get_country_names()
    aggregate_array = [
      {'$unwind': '$address_components'},
      {'$project': {'address_components.long_name': 1, 'address_components.types': 1}},
      {'$match': {'address_components.types': "country"}},
      {'$group': {'_id': '$address_components.long_name'}}
    ]
    result = collection.find.aggregate(aggregate_array).to_a.map {|h| h[:_id]}
  end

  def self.find_ids_by_country_code(country_code)
    aggregate_array = [
      {'$match': {'address_components.short_name': country_code, 'address_components.types': "country"}},
      {'$project': {'_id': 1}},
    ]
    result = collection.find.aggregate(aggregate_array).to_a.map {|h| h[:_id].to_s}
  end

  def self.create_indexes
    collection.indexes.create_one({'geometry.geolocation': Mongo::Index::GEO2DSPHERE})
  end

  def self.remove_indexes
    collection.indexes.drop_one('geometry.geolocation_2dsphere')
  end

  def self.near(point, max_meters = nil)
    request = {:$geometry => point.to_hash}
    request[:$maxDistance] = max_meters if max_meters
    collection.find('geometry.geolocation' => {
      :$near => request
    })
  end

  def near(max_meters = nil)
    self.class.to_places(self.class.near(@location, max_meters))
  end

  def photos(offset = 0, limit = nil)
    result = Photo.find_photos_for_place(BSON::ObjectId.from_string(@id))#.skip(offset)
    result = result.limit(limit) if limit
    ans = []
    result.map {|doc| ans << Photo.new(doc)}
    return ans
  end
end