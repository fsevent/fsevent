# processdevicec.rb --- child process code for processdevice.rb
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

class FSEvent::ProcessDeviceC < FSEvent::AbstractDevice
  class StubFramework
    def initialize(obj)
      @obj = obj
    end

    def add_watch(watchee_device_name, status_name)
      @obj.call_parent(:add_watch, watchee_device_name, status_name)
    end

    def modify_status(status_name, value)
      @obj.call_parent(:modify_status, status_name, value)
    end
  end

  def initialize(device_name)
    super(device_name)
  end

  def processdevice_framework_set
    framework = StubFramework.new(self)
    self.framework = framework
    nil
  end

  def processdevice_registered
    registered
    nil
  end

  def call_parent(method, *args)
    Marshal.dump([:call_parent, method, *args], STDOUT)
    msgtype, *rest = Marshal.load(STDIN)
    while msgtype == :call_child
      method, *args = rest
      ret = self.send(method, *args)
      Marshal.dump([:return_to_parent, ret], STDOUT)
      msgtype, *rest = Marshal.load(STDIN)
    end
    if msgtype != :return_to_child
      raise FSEvent::FSEventError, "unexpected message type: #{msgtype.inspect}"
    end
    rest[0]
  end

  def self.main(this_device)
    STDOUT.sync = true
    while true
      begin
        msgtype, *rest = Marshal.load(STDIN)
      rescue EOFError
        exit true
      end
      if msgtype != :call_child
        raise FSEvent::FSEventError, "unexpected message type: #{msgtype.inspect}"
      end
      method, *args = rest
      ret = this_device.send(method, *args)
      Marshal.dump([:return_to_parent, ret], STDOUT)
    end
  end
end
