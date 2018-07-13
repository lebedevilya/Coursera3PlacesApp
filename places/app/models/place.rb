class Place < ActionController::Base
  include ActiveModel::Model
  helper PlacesHelper
  attr_accessor :id, :formatted_address, :location, :address_components
  def self.mongo_client
    Mongoid::Clients.default
  end

  def initialize(params)
  	@id = params[:_id].to_s
  	@formatted_address = params[:formatted_address]
  	@location = Point.new(params[:geometry][:location])
  	@address_components = []
  	params[:address_components]. each do |address|
  		@address_components << AddressComponent.new(address)
  	end
  end

  def destroy
 #   pp Place.collection.find(:_id => BSON::ObjectId.from_string(@id))
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
    Place.new(self.collection.find({:_id => id}).first)
  end

  def self.all(offset = 0, limit = nil)
    result = collection.find.skip(offset)
    result = result.limit(limit) if limit
    ans = []
    result.each {|p| ans << Place.new(p)}
    return ans
  end
end