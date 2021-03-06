module Events
  class CreateService
    attr_accessor :is_overlap, :event

    def initialize user, params
      @user = user
      @params = params
      @event = user.events.build event_params
      if params["start_time"] and params["finish_time"] and params["start_date"] and params["finish_date"]
        timezone = Settings.users.timezone_default
        if user.setting_timezone.present?
          timezone = user.setting_timezone
        end

        @event.start_date = @event.start_date - timezone.hours
        @event.finish_date = @event.finish_date - timezone.hours
      end
    end

    def perform
      modify_repeat_params if @params[:repeat].nil?
      return false if is_overlap? && not_allow_overlap?
      NotificationWorker.perform_async @event.id if status = @event.save
      return status
    end

    private
    def event_params
      @params.require(:event).permit Event::ATTRIBUTES_PARAMS
    end

    def modify_repeat_params
      Event::REPEAT_PARAMS.each {|attribute| @params[:event].delete attribute}
    end

    def is_overlap?
      overlap_handler = OverlapHandler.new @event
      self.is_overlap = overlap_handler.overlap?
    end

    def not_allow_overlap?
      @params["allow_overlap"] != "true"
    end
  end
end
