# periodicschedule.rb --- periodic schedule
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

class FSEvent::PeriodicSchedule
  def initialize(initial_time, interval)
    @initial_time = initial_time
    @interval = interval
    @n = 0
  end

  def first
    @initial_time + @n * @interval
  end

  def shift
    t = first
    @n += 1
    t
  end
end
