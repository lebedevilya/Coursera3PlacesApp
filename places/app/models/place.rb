class Place
  include ActiveModel::Model

  def self.mongo_client
    Mongoid::Clients.default
  end

  def self.collection
    mongo_client['places']
  end
end