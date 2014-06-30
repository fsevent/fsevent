# valueiddevice.rb --- value identity device
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

class FSEvent::ValueIdDevice < FSEvent::AbstractDevice
  def initialize(device_name, target_device_name, status_name)
    super device_name
    @target_device_name = target_device_name
    @status_name = status_name
    @defined = false
    @old_value = nil
    @id = 0
  end

  def registered
    add_watch @target_device_name, @status_name, :immediate
  end

  def run(watched_status, changed_status)
    if watched_status.has_key?(@target_device_name) && watched_status[@target_device_name].has_key?(@status_name)
      value, id = watched_status[@target_device_name][@status_name]
      if !@defined
        @id += 1
        define_status(@status_name, [value, @id])
        @defined = true
        @old_value = value
      else
        if @old_value != value
          @id += 1
          modify_status(@status_name, [value, @id])
          @old_value = value
        end
      end
    else
      if @defined
        @id += 1
        undefine_status(@status_name)
        @defined = false
        @old_value = nil
      end
    end
  end
end
