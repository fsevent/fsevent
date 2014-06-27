# debugdumper.rb --- device for debug dump
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
class FSEvent::DebugDumper < FSEvent::AbstractDevice
  def initialize(device_name="debugdumper")
    super
  end

  def registered
    add_watch("*", "*")
  end

  def run(watched_status, changed_status)
    #pp watched_status
    pp changed_status
  end
end
