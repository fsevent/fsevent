# simpledevice.rb --- simple device definition using constructor arguments
#
# Copyright (C) 2014  National Institute of Advanced Industrial Science and Technology (AIST)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

class FSEvent::SimpleDevice < FSEvent::AbstractDevice
  def initialize(device_name, initial_status, watches, registered_elapsed_time, schedule=nil, &run_block)
    super device_name
    @name = device_name
    @initial_status = initial_status
    @watches = watches
    @registered_elapsed_time = registered_elapsed_time
    @schedule.merge_schedule schedule if schedule
    @run_block = run_block
  end
  attr_writer :registered_elapsed_time

  def registered
    @initial_status.each {|status_name, value|
      define_status status_name, value
    }
    @watches.each {|watchee_device_name, status_name, reaction|
      reaction ||= :immediate
      add_watch watchee_device_name, status_name, reaction
    }
    if @registered_elapsed_time
      set_elapsed_time @registered_elapsed_time
    end
  end

  def run(watched_status_change)
    @run_block.call watched_status_change
  end
end
