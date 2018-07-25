class AddressComponent
  attr_reader :long_name, :short_name, :types

  def initialize(params={})
  	if params.empty?
  		@long_name = "Empty"
  		@short_name = "Params"
  		@types = ["Passed", "To initializer"]
  	else
  		@long_name = params[:long_name]
  		@short_name = params[:short_name]
  		@types = params[:types]
  	end
  end
end