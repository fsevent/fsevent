# failsafedevice.rb --- fail safe device class
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

class FSEvent::FailSafeDevice < FSEvent::AbstractDevice
  def initialize(device_name, initial_status, *watchee_device_names)
    super device_name
    raise "One devices required at least" if watchee_device_names.empty?
    @current_status = {} # status_name -> value
    @current_status_list = {} # status_name -> watchee_device_name -> value
    @status_merger = {}
    initial_status.each {|k, v, merger|
      @current_status[k] = v
      @status_merger[k] = merger_callable(merger)
      @current_status_list[k] = {}
      watchee_device_names.each {|watchee_device_name|
        @current_status_list[k][watchee_device_name] = v
      }
    }
    @watchee_device_names = watchee_device_names
  end

  def merger_callable(merger)
    case merger
    when :max
      method(:merger_max)
    when :min
      method(:merger_min)
    when :lazy
      method(:merger_lazy)
    else
      merger
    end
  end

  def merger_max(cur, *values) values.max end
  def merger_min(cur, *values) values.min end
  def merger_lazy(cur, *values) values.uniq.length == 1 ? values[0] : cur end

  def registered
    @watchee_device_names.each {|n|
      @current_status.each {|k, v|
        add_watch n, k
      }
    }
    @current_status.each {|k, v|
      define_status k, v
    }
  end

  def run(watched_status, changed_status)
    updated = {}
    changed_status.each {|watchee_device_name, h|
      h.each {|status_name, time|
        next if /\A_/ =~ status_name
        value = watched_status[watchee_device_name][status_name]
        unless updated.has_key? status_name
          updated[status_name] = @current_status_list[status_name]
        end
        updated[status_name][watchee_device_name] = value
      }
    }
    updated.each {|status_name, h|
      merger = @status_merger[status_name]
      cur_val = @current_status[status_name]
      values = @watchee_device_names.map {|d| h[d] }
      new_val = merger.call(cur_val, *values)
      if cur_val != new_val
        @current_status[status_name] = new_val
        status_changed status_name, new_val
      end
    }
  end
end
