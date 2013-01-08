module Merit
  # Sets up an app-wide after_filter, and inserts merit_action entries if
  # there are defined rules (for badges or points) for current
  # 'controller_path#action_name'
  module ControllerExtensions
    def self.included(base)
      base.after_filter do |controller|
        process_merit_events
      end if Merit.add_after_filter
    end

    private

    def process_merit_events
      if rules_defined?
        log_merit_action
        Merit::Action.check_unprocessed if Merit.checks_on_each_request    
      end
    end

    def log_merit_action
      Merit::Action.create(
        :user_id       => send(Merit.current_user_method).try(:id),
        :action_method => action_name,
        :action_value  => params[:value],
        :had_errors    => had_errors?,
        :target_model  => controller_name,
        :target_id     => target_id
      ).id
    end

    def rules_defined?
      action = "#{controller_name}\##{action_name}"
      AppBadgeRules[action].present? || AppPointRules[action].present?
    end

    def had_errors?
      target_object.respond_to?(:errors) && target_object.errors.try(:present?)
    end

    def target_object
      target_obj = instance_variable_get(:"@#{controller_name.singularize}")
      if target_obj.nil?
        Rails.logger.warn("[merit] No object found, maybe you need a '@#{controller_name.singularize}' variable in '#{controller_path}_controller'?")
      end
      target_obj
    end

    def target_id
      target_id = params[:id] || target_object.try(:id)
      # using friendly_id if id is nil or string but an object was found
      if target_object.present? && (target_id.nil? || !(target_id =~ /^[0-9]+$/))
        target_id = target_object.id
      end
      target_id
    end
  end
end
