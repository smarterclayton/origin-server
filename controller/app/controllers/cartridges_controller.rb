##
# Cartridge list API
# @api REST
class CartridgesController < BaseController
  include RestModelHelper
  skip_before_filter :authenticate_user!

  ##
  # Retrieve details for specific cartridge
  #
  # URL: /cartridge/:name
  #
  # @note This method may or may not require authenticated access depending on the authentication plugin that is configured.
  #
  # Action: GET
  # @return [RestReply<RestCartridge>] Cartridge Object
  def show
    id = params[:id].presence
    if id == "embedded" or id == "standalone"
      #for backward compatibility get all cartridges matching
      index

    else
      c = CartridgeCache.find_cartridge(ComponentInstance.check_name!(id)) or
        raise Mongoid::Errors::DocumentNotFound.new(CartridgeType, name: id)
      render_success(:ok, "cartridge", get_rest_cartridge(c), "Cartridge #{id} found")
    end
  end

  ##
  # Retrieve details for all available cartridge
  #
  # URL: /cartridges
  #
  # @note This method may or may not require authenticated access depending on the authentication plugin that is configured.
  #
  # Action: GET
  # @return [RestReply<Array<RestCartridge>>] Array of cartridge objects
  def index
    searching = false
    carts = CartridgeType.active.order_by(:name => 1)

    # Legacy support for cartridges/standalone|embedded
    feature = params[:feature].presence
    category = params[:category].presence || params[:id].presence
    if ['standalone','embedded'].include?(feature)
      category = feature
      feature = nil
    end

    category = 'web_framework' if category == 'standalone'
    if category == "embedded"
      searching = true
      carts = carts.not_in(categories: 'web_framework')

    elsif category
      searching = true
      carts = carts.in(categories: category)

    elsif feature = params[:feature].presence
      searching = true
      carts = carts.in(provides: feature)
    end
    carts = carts.sort_by(&OpenShift::Cartridge::NAME_PRECEDENCE_ORDER)

    render_success(:ok, "cartridges", carts.map{ |c| get_rest_cartridge(c) }, "#{searching ? "Searching" : "Listing"} cartridges")
  end
end
