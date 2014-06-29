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
    # valid values of reaction: :immediate, :schedule
    @watch_defs = nested_hash(3) # watcher_device_name -> watchee_device_name_pat -> status_name_pat -> reaction

    @watch_exact_exact = nested_hash(3) # watchee_device_name_exact -> status_name_exact -> watcher_device_name -> reaction
    @watch_exact_prefix = nested_hash(3) # watchee_device_name_exact -> status_name_prefix -> watcher_device_name -> reaction
    @watch_prefix_exact = nested_hash(3) # watchee_device_name_prefix -> status_name_exact -> watcher_device_name -> reaction
    @watch_prefix_prefix = nested_hash(3) # watchee_device_name_prefix -> status_name_prefix -> watcher_device_name -> reaction
  end

  def add(watchee_device_name_pat, status_name_pat, watcher_device_name, reaction)
    @watch_defs[watcher_device_name][watchee_device_name_pat][status_name_pat] = reaction
    if /\*\z/ =~ watchee_device_name_pat
      watchee_device_name_prefix = $`
      if /\*\z/ =~ status_name_pat
        status_name_prefix = $`
        @watch_prefix_prefix[watchee_device_name_prefix][status_name_prefix][watcher_device_name] = reaction
      else
        @watch_prefix_exact[watchee_device_name_prefix][status_name_pat][watcher_device_name] = reaction
      end
    else
      if /\*\z/ =~ status_name_pat
        status_name_prefix = $`
        @watch_exact_prefix[watchee_device_name_pat][status_name_prefix][watcher_device_name] = reaction
      else
        @watch_exact_exact[watchee_device_name_pat][status_name_pat][watcher_device_name] = reaction
      end
    end
  end

  def del(watchee_device_name_pat, status_name_pat, watcher_device_name)
    @watch_defs[watcher_device_name][watchee_device_name_pat].delete status_name_pat
    if /\*\z/ =~ watchee_device_name_pat
      watchee_device_name_prefix = $`
      if /\*\z/ =~ status_name_pat
        status_name_prefix = $`
        @watch_prefix_prefix[watchee_device_name_prefix][status_name_prefix].delete watcher_device_name
      else
        @watch_prefix_exact[watchee_device_name_prefix][status_name_pat].delete watcher_device_name
      end
    else
      if /\*\z/ =~ status_name_pat
        status_name_prefix = $`
        @watch_exact_prefix[watchee_device_name_pat][status_name_prefix].delete watcher_device_name
      else
        @watch_exact_exact[watchee_device_name_pat][status_name_pat].delete watcher_device_name
      end
    end
  end

  def lookup_watchers(watchee_device_name, status_name)
    # needs cache for performance?
    result = []
    if @watch_exact_exact.has_key?(watchee_device_name) &&
       @watch_exact_exact[watchee_device_name].has_key?(status_name)
      @watch_exact_exact[watchee_device_name][status_name].each {|watcher_device_name, reaction|
        result << [watcher_device_name, reaction]
      }
    end
    if @watch_exact_prefix.has_key?(watchee_device_name)
      @watch_exact_prefix[watchee_device_name].each {|status_name_prefix, h| # linear search.  can be slow.
        if status_name.start_with? status_name_prefix
          h.each {|watcher_device_name, reaction|
            result << [watcher_device_name, reaction]
          }
        end
      }
    end
    @watch_prefix_exact.each {|watchee_device_name_prefix, h1| # linear search.  can be slow.
      next unless watchee_device_name.start_with? watchee_device_name_prefix
      if @watch_prefix_exact[watchee_device_name_prefix].has_key?(status_name)
        @watch_prefix_exact[watchee_device_name_prefix][status_name].each {|watcher_device_name, reaction|
          result << [watcher_device_name, reaction]
        }
      end
    }
    @watch_prefix_prefix.each {|watchee_device_name_prefix, h1| # linear search.  can be slow.
      next unless watchee_device_name.start_with? watchee_device_name_prefix
      @watch_prefix_prefix[watchee_device_name_prefix].each {|status_name_prefix, h| # linear search.  can be slow.
        if status_name.start_with? status_name_prefix
          h.each {|watcher_device_name, reaction|
            result << [watcher_device_name, reaction]
          }
        end
      }
    }
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

    [@watch_exact_exact,
     @watch_exact_prefix,
     @watch_prefix_exact,
     @watch_prefix_prefix].each {|h0|
      h0.each {|watchee_device_name, h1|
        h1.each {|status_name, h2|
          h2.delete watcher_device_name
        }
      }
    }
  end
end
