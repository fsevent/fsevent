# util.rb --- various utilities
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

module FSEvent::Util
  module_function

  def nested_hash(n)
    if n == 1
      {}
    else
      Hash.new {|h, k|
        h[k] = nested_hash(n-1)
      }
    end
  end

  def nonempty_hash(h, level)
    return nil if h.nil?
    result = {}
    h.each {|k, v|
      if level == 1
        result[k] = v
      else
        h2 = nonempty_hash(v, level-1)
        if h2
          result[k] = h2
        end
      end
    }
    if result.empty?
      nil
    else
      result
    end
  end

  def valid_device_name_for_read?(str)
    /\A_?[a-z][a-z0-9_]*\z/ =~ str
  end

  def valid_device_name_pat_for_read?(str)
    /\A_?(?:[a-z][a-z0-9_]*)?\*?\z/ =~ str
  end

  def valid_status_name_for_read?(str)
    /\A_?[a-z][a-z0-9_]*\z/ =~ str
  end

  def valid_status_name_pat_for_read?(str)
    /\A_?(?:[a-z][a-z0-9_]*)?\*?\z/ =~ str
  end

  def valid_device_name_for_write?(str)
    /\A[a-z][a-z0-9_]*\z/ =~ str
  end

  def valid_status_name_for_write?(str)
    /\A[a-z][a-z0-9_]*\z/ =~ str
  end

  def prefixpat_match(pat, str)
    if /\*\z/ =~ pat
      str.start_with?($`)
    else
      pat == str
    end
  end

  def reaction_immediate_at_beginning?(reaction)
    case reaction
    when :immediate
      true
    when :schedule
      false
    else
      raise ArgumentError, "unexpected reaction: #{reaction.inspect}"
    end
  end

  def reaction_immediate_at_subsequent?(reaction)
    case reaction
    when :immediate
      true
    when :schedule
      false
    else
      raise ArgumentError, "unexpected reaction: #{reaction.inspect}"
    end
  end

end
