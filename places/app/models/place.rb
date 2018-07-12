class Place
  attr_accessor :id, :formatted_address, :location, :address_components
  def self.mongo_client
    Mongoid::Clients.default
  end

  def initialize(params={})
  	@id = params[:_id].to_s
  	@formatted_address = params[:formatted_address]
  	@location = Point.new(params[:geometry][:location])
  	@address_components = []
  	params[:address_components]. each do |address|
  		@address_components << AddressComponent.new(address)
  	end
  end

  def self.collection
    mongo_client['places']
  end

  def self.load_all(f)
  	places=JSON.parse(f.read)
  	self.collection.insert_many(places)
  end
end