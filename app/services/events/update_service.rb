module Events
  class UpdateService
    attr_accessor :is_overlap, :event

    def initialize user, event, params
      @user = user
      @event = event
      @params = params
      if params["start_time"] and params["finish_time"] and params["start_date"] and params["finish_date"]
        timezone = Settings.users.timezone_default
        if user.setting_timezone.present?
          timezone = user.setting_timezone
        end
        @params["event"]["start_date"] = @params["event"]["start_date"].in_time_zone - timezone.hours
        @params["event"]["finish_date"] = @params["event"]["finish_date"].in_time_zone - timezone.hours
      end
    end

    def perform
      modify_repeat_params if @params[:repeat].blank?
      @params[:event] = @params[:event].merge({
        exception_time: event_params[:start_date],
        start_repeat: start_repeat,
        end_repeat: end_repeat
      })

      if change_datetime? && is_overlap? && allow_overlap?
        return false
      else
        exception_service = Events::ExceptionService.new(@event, @params)
        exception_service.perform
        self.event = exception_service.new_event
        return true
      end
    end

    private
    def event_params
      @params.require(:event).permit Event::ATTRIBUTES_PARAMS
    end

    def handle_event_params
      @params.require(:event).permit Event::ATTRIBUTES_PARAMS[1..-2]
    end

    def modify_repeat_params
      Event::REPEAT_PARAMS.each{|attribute| @params[:event].delete attribute}
    end

    def is_overlap?
      event = Event.new handle_event_params
      event.parent_id = @event.parent? ? @event.id : @event.parent_id
      event.calendar_id = @event.calendar_id
      overlap_handler = OverlapHandler.new(event)
      self.is_overlap = overlap_handler.overlap?
    end

    def allow_overlap?
      @params[:allow_overlap] != "true"
    end

    def start_repeat
      event_params[:start_repeat] || event_params[:start_date]
    end

    def end_repeat
      event_params[:end_repeat] || @event.end_repeat
    end

    def change_datetime?
      event_hour_minute = @event.start_date.strftime("%H:%M")
      event_hour_minute = event_params[:start_date].to_datetime.strftime("%H:%M")
      event_hour_minute != event_hour_minute
    end
  end
end
