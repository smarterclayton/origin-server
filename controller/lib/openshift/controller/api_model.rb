module OpenShift::Controller
  module ApiModel
    extend ActiveSupport::Concern

    def rest_api
      @rest_api ||= self.class.rest_api_model.new(self)
    end

    module ClassMethods
      def rest_api_model
        @rest_api_model ||= begin
          "Rest::#{model_name}".safe_constantize || SimpleDelegator
        end
      end
    end
  end
end