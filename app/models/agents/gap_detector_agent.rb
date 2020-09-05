module Agents
  class GapDetectorAgent < Agent
    default_schedule "every_10m"

    description <<-MD
      The Gap Detector Agent will watch for holes or gaps in a stream of incoming Events and generate "no data alerts".

      The `value_path` values is a [JSONPath](http://goessner.net/articles/JsonPath/) to a value of interest. If either
      this value is empty, or no Events are received, during `window_duration_in_days`, an Event will be created with
      a payload of `message`.
    
      `alert_on_every_run` will create an event on every run when the `window_duration_in_days` has elapsed since the last event.

    MD

    event_description <<-MD
      Events look like:

          {
            "message": "No data has been received!",
            "gap_started_at": "1234567890"
          }
    MD

    def validate_options
      unless options['message'].present?
        errors.add(:base, "message is required")
      end

      unless options['window_duration_in_days'].present? && options['window_duration_in_days'].to_f > 0
        errors.add(:base, "window_duration_in_days must be provided as an integer or floating point number")
      end
    end

    def default_options
      {
        'window_duration_in_days' => "2",
        'message' => "No data has been received!",
	'alert_on_every_run' => false 
      }
    end

    def working?
      true
    end

    def receive(incoming_events)
      incoming_events.sort_by(&:created_at).each do |event|
        memory['newest_event_created_at'] ||= 0

        if !interpolated['value_path'].present? || Utils.value_at(event.payload, interpolated['value_path']).present?
          if event.created_at.to_i > memory['newest_event_created_at']
            memory['newest_event_created_at'] = event.created_at.to_i
            memory.delete('alerted_at')
          end
        end
      end
    end

    def check
      window = interpolated['window_duration_in_days'].to_f.days.ago
      if memory['newest_event_created_at'].present? && Time.at(memory['newest_event_created_at']) < window
        if !memory['alerted_at'] || (interpolated['alert_on_every_run'].present? && interpolated['alert_on_every_run'] == "true")
          memory['alerted_at'] = Time.now.to_i
          create_event payload: { message: interpolated['message'],
                                  gap_started_at: memory['newest_event_created_at'] }
	end
      end
    end
  end
end
