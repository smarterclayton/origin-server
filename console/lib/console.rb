module Console
  class AccessDenied < StandardError ; end
  class ApiNotAvailable < StandardError ; end
  class NotFound < StandardError ; end
end

require 'console/version'
require 'console/engine'

