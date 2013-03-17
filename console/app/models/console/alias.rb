#
# The REST API model object representing a domain name alias to an application.
#
class Console::Alias < Console::RestApi::Base
  schema do
    string :name
  end

  belongs_to :application
end
