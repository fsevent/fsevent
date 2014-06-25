#!/usr/bin/ruby

require 'time'
require 'fsevent'

class Repeater < FSEvent::AbstractDevice
  def initialize(name, schedule)
    super name
    @schedule = schedule
  end

  def run(watched_status, changed_status)
    @framework.set_elapsed_time(1)
    p @framework.current_time.iso8601(3)
  end
end

schedule = FSEvent::PeriodicSchedule.new(Time.utc(2000), 10)
repeat = Repeater.new("repeat", schedule)

fsevent = FSEvent.new(Time.utc(2000))
fsevent.register_device(repeat)
fsevent.start

