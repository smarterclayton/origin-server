module Membership
  extend ActiveSupport::Concern

  def members
    attributes[:members] || []
  end

  def owner?
    members.find{ |m| m.id == api_identity_id && m.owner? } if api_identity_id
  end

  def admin?
    has_role?('admin')
  end

  def editor?
    has_role?('admin','edit')
  end

  def readonly?
    has_role?('view')
  end

  def has_role?(*roles)
    roles.present? and api_identity_id.present? and members.find{ |m| m.id == api_identity_id && roles.include?(m.role) }
  end

  # FIXME Refactor this method into a patch_child_collection operation on RestApi::Base
  def update_members(members)
    self.errors.clear
    self.messages.clear
    body = {
      :members => members.map do |m|
        {
          :id => (m.id if m.respond_to? :id),
          :login => (m.login if m.respond_to? :login),
          :role => m.role
        }
      end
    }
    response = post(:members, nil, body.to_json)
    self.messages = extract_messages(response)
    resource = self.class.format.decode(response.body)
    p = child_prefix_options
    if resource.is_a? Array
      self.attributes[:members] = resource.map{ |r| m = self.class.member_resource.new(r, true, p); m.as = as; m }
    else
      m = self.class.member_resource.new(resource, true, p)
      m.as = as
      self.members.delete_if{ |o| o == m }
      self.members << m
    end
    true
  rescue ActiveResource::ConnectionError => e
    if e.respond_to? :response
      set_remote_errors(e.response, true)
    else
      self.messages = [RestApi::Base::Message.new(0, nil, 'error', $!.to_s)]
    end
    false
  end

  module ClassMethods
    def has_members(options={})
      has_many :members, :class_name => options[:as]
      @member_resource = options[:as]
    end
    attr_reader :member_resource
  end
end
