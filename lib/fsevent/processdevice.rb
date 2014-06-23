# processdevice.rb --- run device on another process
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

class FSEvent::ProcessDevice < FSEvent::AbstractDevice
  def self.spawner(defs)
    Spawner.new(defs)
  end

  class Spawner
    def initialize(defs)
      @defs = defs
    end

    def assemble_code(device_name, *args)
      code = ''

      libpath = File.dirname(File.dirname(__FILE__))
      code << "$:.unshift #{libpath.dump}\n"

      code << <<-'End'
        require 'fsevent'
        def ep(arg) STDERR.puts arg.inspect end
      End

      code << "class FSEvent::ProcessDevice_#{device_name} < FSEvent::ProcessDeviceC\n#{@defs}\nend\n"
      marshaled_args = Marshal.dump(args)
      code << "FSEvent::ProcessDeviceC.main(FSEvent::ProcessDevice_#{device_name}.new(#{device_name.dump}, *(Marshal.load(#{marshaled_args.dump}))))\n"
    end

    def new(device_name, *args)
      code = assemble_code(device_name, *args)
      io = IO.popen([RbConfig.ruby], "r+")
      io.sync = true
      io.write code
      io.write "__END__\n"
      FSEvent::ProcessDevice.send(:new, device_name, io)
    end
  end

  class << self
    private :new
  end

  def initialize(device_name, io)
    super device_name
    @io = io
  end

  def call_subprocess(method, *args)
    Marshal.dump([:call_child, method, *args], @io)
    msgtype, *rest = Marshal.load(@io)
    while msgtype == :call_parent
      method, *args = rest
      ret = @framework.send(method, *args)
      Marshal.dump([:return_to_child, ret], @io)
      msgtype, *rest = Marshal.load(@io)
    end
    if msgtype != :return_to_parent
      raise RuntimeError, "unexpected message type: #{msgtype.inspect}"
    end
    rest[0]
  end
  #private :call_subprocess

  def finish
    @io.close_write
    @io.close
    nil
  end

  def framework=(framework)
    @framework = framework
    call_subprocess(:processdevice_framework_set)
  end

  def registered
    call_subprocess(:processdevice_registered)
  end
end
