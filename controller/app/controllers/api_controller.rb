class ApiController < BaseController

  skip_before_filter :authenticate_user!, :only => :show

  def show
    blacklisted_words = OpenShift::ApplicationContainerProxy.get_blacklisted
    unless nolinks
      links = {
        "API" => Link.new("API entry point", "GET", URI::join(get_url, "api")),
        "GET_ENVIRONMENT" => Link.new("Get environment information", "GET", URI::join(get_url, "environment")),
        "GET_USER" => Link.new("Get user information", "GET", URI::join(get_url, "user")),      
        "LIST_DOMAINS" => Link.new("List domains", "GET", URI::join(get_url, "domains")),
        "ADD_DOMAIN" => Link.new("Create new domain", "POST", URI::join(get_url, "domains"), [
          Param.new("id", "string", "Name of the domain",nil,blacklisted_words)
        ]),
        "LIST_CARTRIDGES" => Link.new("List cartridges", "GET", URI::join(get_url, "cartridges")),

        "LIST_AUTHORIZATIONS" => Link.new("List authorizations", "GET", URI::join(get_url, "user/authorizations")),
        "SHOW_AUTHORIZATION"  => Link.new("Retrieve authorization :id", "GET", URI::join(get_url, "user/authorizations/:id"), [
          Param.new(":id", "string", "Unique identifier of the authorization", nil, [])
        ]),
        "ADD_AUTHORIZATION" => Link.new("Add new authorization", "POST", URI::join(get_url, "user/authorizations"), [], [
          OptionalParam.new("note", "string", "A description to remind you what this authorization is for."),
          OptionalParam.new("expires_in", "int", "The number of seconds before this authorization expires. Out of range values will be set to the maximum allowed time.", nil, -1),
        ]),
      }

      base_url = Rails.application.config.openshift[:community_quickstarts_url]
      if base_url.nil?
        quickstart_links = {
          "LIST_QUICKSTARTS"   => Link.new("List quickstarts", "GET", URI::join(get_url, "quickstarts")),
          "SHOW_QUICKSTART"    => Link.new("Retrieve quickstart with :id", "GET", URI::join(get_url, "quickstarts/:id"), [
            Param.new(":id", "string", "Unique identifier of the quickstart", nil, [])
          ]),
        }
        links.merge! quickstart_links
      else
        base_url = URI.join(get_url, base_url).to_s
        quickstart_links = {
          "LIST_QUICKSTARTS"   => Link.new("List quickstarts", "GET", URI::join(base_url, "v1/quickstarts/promoted.json")),
          "SHOW_QUICKSTART"    => Link.new("Retrieve quickstart with :id", "GET", URI::join(base_url, "v1/quickstarts/:id"), [
            Param.new(":id", "string", "Unique identifier of the quickstart", nil, [])
          ]),
          "SEARCH_QUICKSTARTS" => Link.new("Search quickstarts", "GET", URI::join(base_url, "v1/quickstarts.json"), [
            Param.new("search", "string", "The search term to use for the quickstart", nil, [])
          ]),
        }
        links.merge! quickstart_links
      end
    end

    @reply = RestReply.new(requested_api_version, :ok, "links", links)
    respond_with @reply, :status => @reply.status
  end
end
