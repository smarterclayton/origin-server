class CartridgesController < BaseController
  skip_before_filter :authenticate_user!

  def show
    index
  end

  # GET /cartridges
  def index
    type = params[:id]
    if type.nil?
      cartridges = CartridgeCache.cartridges
    else
      cartridges = CartridgeCache.cartridges.keep_if{ |c| c.categories.include?(type) }
    end

    cartridges.map! do |c|
      if $requested_api_version == 1.0
        RestCartridge10.new(c, nil, nil, get_url, nil, nolinks)
      else
        RestCartridge.new(c, nil, nil, nil, nil, nil, get_url, nil, nolinks)
      end
    end
    render_success(:ok, "cartridges", cartridges, "LIST_CARTRIDGES", "List #{type.nil? ? 'all' : type} cartridges")
  end
end
