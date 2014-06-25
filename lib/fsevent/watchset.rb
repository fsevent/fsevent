# watchset.rb --- set of watches
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

class FSEvent::WatchSet
  include FSEvent::Util

  def initialize
    # valid values of reaction: :immediate, :immediate_only_at_beginning, :schedule
    @watch_defs = nested_hash(3) # watcher_device_name -> watchee_device_name_pat -> status_name_pat -> reaction
    @watch_reactions = nested_hash(3) # watchee_device_name_pat -> status_name_pat -> watcher_device_name -> reaction
  end

  def add(watchee_device_name_pat, status_name_pat, watcher_device_name, reaction)
    @watch_defs[watcher_device_name][watchee_device_name_pat][status_name_pat] = reaction
    @watch_reactions[watchee_device_name_pat][status_name_pat][watcher_device_name] = reaction
  end

  def del(watchee_device_name_pat, status_name_pat, watcher_device_name)
    @watch_defs[watcher_device_name][watchee_device_name_pat].delete status_name_pat
    @watch_reactions[watchee_device_name_pat][status_name_pat].delete watcher_device_name
  end

  def lookup_watchers(watchee_device_name, status_name)
    # xxx: prefix match not supported
    result = []
    if @watch_reactions.has_key?(watchee_device_name) &&
       @watch_reactions[watchee_device_name].has_key?(status_name)
      @watch_reactions[watchee_device_name][status_name].each {|watcher_device_name, reaction|
        result << [watcher_device_name, reaction]
      }
    end
    result
  end

  def watcher_each(watcher_device_name)
    return unless @watch_defs.has_key? watcher_device_name
    @watch_defs[watcher_device_name].each {|watchee_device_name_pat, h|
      h.each {|status_name_pat, reaction|
        yield watchee_device_name_pat, status_name_pat, reaction
      }
    }
  end

  def delete_watcher(watcher_device_name)
    @watch_defs.delete watcher_device_name
    @watch_reactions.each {|watchee_device_name, h1|
      h1.each {|status_name, h2|
        h2.delete watcher_device_name
      }
    }
  end
end
