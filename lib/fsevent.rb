# fsevent.rb --- library file to be required by users
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

require 'rbconfig'
require 'depq'
require 'pp'

class FSEvent
  class FSEventError < StandardError
  end
end

require 'fsevent/util'
require 'fsevent/watchset'
require 'fsevent/framework'
require 'fsevent/abstractdevice'
require 'fsevent/debugdumper'
require 'fsevent/simpledevice'
require 'fsevent/processdevice'
require 'fsevent/processdevicec'
require 'fsevent/failsafedevice'
require 'fsevent/schedulemerger'
require 'fsevent/periodicschedule'
require 'fsevent/valueiddevice'
