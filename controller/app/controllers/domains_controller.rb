# @api REST
class DomainsController < BaseController
  include RestModelHelper
  before_filter :get_domain, :only => [:show, :destroy]
  # Retuns list of domains for the current user
  # 
  # URL: /domains
  #
  # Action: GET
  # 
  # @return [RestReply<Array<RestDomain>>] List of domains
  def index
    rest_domains = Array.new
    Rails.logger.debug "Getting domains for user #{@cloud_user.login}"
    domains = Domain.accessible(current_user)
    domains.each do |domain|
      rest_domains.push get_rest_domain(domain)
    end
    render_success(:ok, "domains", rest_domains)
  end

  # Retuns domain for the current user that match the given parameters.
  # 
  # URL: /domains/:id
  #
  # Action: GET
  # 
  # @param [String] id The namespace of the domain
  # @return [RestReply<RestDomain>] The requested domain
  def show
    render_success(:ok, "domain", get_rest_domain(@domain), "Found domain #{@domain.namespace}")
  end

  # Create a new domain for the user
  # 
  # URL: /domains
  #
  # Action: POST
  #
  # @param [String] id The namespace for the domain
  # 
  # @return [RestReply<RestDomain>] The new domain
  def create
    authorize! :create_domain, @cloud_user

    namespace = params[:id].downcase if params[:id].presence
    Rails.logger.debug "Creating domain with namespace #{namespace}"

    return render_error(:unprocessable_entity, "Namespace is required and cannot be blank.",
                        106, "id") if !namespace or namespace.empty?

    domain = Domain.new(namespace: namespace, owner: @cloud_user)
    if not domain.valid?
      Rails.logger.error "Domain is not valid"
      messages = get_error_messages(domain, {"namespace" => "id"})
      return render_error(:unprocessable_entity, nil, nil, nil, nil, messages)
    end

    if Domain.where(canonical_namespace: namespace).count > 0 
      return render_error(:unprocessable_entity, "Namespace '#{namespace}' is already in use. Please choose another.", 103, "id")
    end

    if Domain.where(owner: @cloud_user).count > 0
      return render_error(:conflict, "There is already a namespace associated with this user", 103, "id")
    end

    @domain_name = domain.namespace

    domain.save

    render_success(:created, "domain", get_rest_domain(domain), "Created domain with namespace #{namespace}")
  end

  # Create a new domain for the user
  # 
  # URL: /domains/:existing_id
  #
  # Action: PUT
  #
  # @param [String] id The new namespace for the domain
  # @param [String] existing_id The current namespace for the domain
  # 
  # @return [RestReply<RestDomain>] The updated domain
  def update
    id = params[:existing_id].downcase if params[:existing_id].presence

    new_gear_sizes = params[:allowed_gear_sizes]
    new_namespace = params[:id].downcase if params[:id].presence
    return render_error(:unprocessable_entity, "Namespace is required and cannot be blank.",106, "id") if new_namespace.empty? && new_gear_sizes.nil?

    domain = Domain.accessible(current_user).find_by(canonical_namespace: Domain.check_name!(id))
    authorize! :change_namespace, domain

    existing_namespace = domain.namespace
    @domain_name = domain.namespace

    # set the new namespace for validation 
    domain.namespace = new_namespace
    if not domain.valid?
      messages = get_error_messages(domain, {"namespace" => "id"})
      return render_error(:unprocessable_entity, nil, nil, nil, nil, messages)
    end
    
    #reset the old namespace for use in update_namespace
    domain.namespace = existing_namespace
    
    @domain_name = domain.namespace
    Rails.logger.debug "Updating domain #{domain.namespace} to #{new_namespace}"

    result = domain.update_namespace(new_namespace)
    domain.save
    
    render_success(:ok, "domain", get_rest_domain(domain), "Updated domain #{id} to #{new_namespace}", result)
  end

  # Delete a domain for the user. Requires that domain be empty unless 'force' parameter is set.
  # 
  # URL: /domains/:id
  #
  # Action: DELETE
  #
  # @param [Boolean] force If true, broker will destroy all application within the domain and then destroy the domain
  def destroy
    id = params[:id].downcase if params[:id].presence
    force = get_bool(params[:force])

    authorize! :destroy, @domain

    if force
      while (apps = Application.where(domain_id: @domain._id)).present?
        apps.each(&:destroy_app)
      end
    elsif Application.where(domain_id: @domain._id).present?
      if requested_api_version <= 1.3
        return render_error(:bad_request, "Domain contains applications. Delete applications first or set force to true.", 128)
      else
        return render_error(:unprocessable_entity, "Domain contains applications. Delete applications first or set force to true.", 128)
      end
    end

    # reload the domain so that MongoId does not see any applications
    @domain.reload
    result = @domain.delete
    status = requested_api_version <= 1.4 ? :no_content : :ok
    render_success(status, nil, nil, "Domain #{id} deleted.", result)
  end
end
