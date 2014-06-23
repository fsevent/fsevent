# schedulemerger.rb --- merge multiple schedules
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

class FSEvent::ScheduleMerger
  def initialize(*schedules)
    @q = Depq.new
    schedules.each {|s|
      merge_schedule(s)
    }
  end

  def merge_schedule(s)
    t = s.shift
    if t
      @q.insert s, t
    end
  end

  def first
    return nil if @q.empty?
    @q.find_min_priority[1]
  end

  def shift
    return nil if @q.empty?
    s, t = @q.delete_min_priority
    t2 = s.shift
    if t2
      @q.insert s, t2
    end
    t
  end
end

