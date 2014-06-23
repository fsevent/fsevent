#!/usr/bin/ruby

require 'fsevent'

class Repeater < FSEvent::AbstractDevice
  def initialize(name, schedule)
    super name
    @schedule = schedule
  end

  def run(watched_status_change)
    p [self.name, @framework.current_time]
  end
end

repeat1 = Repeater.new("repeat1", FSEvent::PeriodicSchedule.new(Time.now, 3))
repeat2 = Repeater.new("repeat2", FSEvent::PeriodicSchedule.new(Time.now, 10))

fsevent = FSEvent.new
fsevent.register_device(repeat1)
fsevent.register_device(repeat2)
fsevent.start

