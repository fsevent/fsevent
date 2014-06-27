# abstractdevice.rb --- abstract device definition
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

# Abstract class for devices
#
class FSEvent::AbstractDevice
  def initialize(device_name)
    @name = device_name
    @current_status = {}
    @schedule = FSEvent::ScheduleMerger.new
  end
  attr_reader :name, :schedule
  attr_writer :framework

  def inspect
    "\#<#{self.class}: #{@name}>"
  end

  # Called from the framework when this device is registered.
  def registered
    # child process calls:
    # * add_watch
    # * del_watch # possible but needless
    # * define_status
    # * modify_status # possible but needless
    # * undefine_status # possible but needless
    # * set_elapsed_time
  end

  # Called from the framework when this device is unregistered.
  def unregistered
  end

  # Called from the framework
  def run(watched_status, changed_status)
    raise NotImplementedError
    # child process calls:
    # * add_watch # possible but should be rare
    # * del_watch
    # * define_status # possible but should be rare
    # * modify_status
    # * undefine_status
    # * set_elapsed_time
  end

  def add_watch(watchee_device_name, status_name, reaction = :immediate)
    @framework.add_watch(watchee_device_name, status_name, reaction)
  end

  def del_watch(watchee_device_name, status_name)
    @framework.del_watch(watchee_device_name, status_name)
  end

  def define_status(status_name, value)
    @framework.define_status(status_name, value)
  end

  def modify_status(status_name, value)
    @framework.modify_status(status_name, value)
  end

  def undefine_status(status_name)
    @framework.undefine_status(status_name)
  end

  def register_device(device)
    @framework.register_device(device)
  end

  def unregister_device(device_name)
    @framework.unregister_device(device_name)
  end

  def set_elapsed_time(t)
    @framework.set_elapsed_time(t)
  end
end
