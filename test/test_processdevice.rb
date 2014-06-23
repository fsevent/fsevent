# test_processdevice.rb --- tests for processdevice.rb
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

require 'test/unit'
require 'fsevent'

class TestFSEventProcessDevice < Test::Unit::TestCase
  def test_empty_definition_and_finish
    d = FSEvent::ProcessDevice.spawner("").new("dname")
    assert_kind_of(FSEvent::ProcessDevice, d)
    assert_equal(nil, d.finish)
  end

  def test_name_call
    d = FSEvent::ProcessDevice.spawner("").new("dname")
    assert_equal("dname", d.call_subprocess(:name))
  ensure
    d.finish
  end

  def test_eval
    d = FSEvent::ProcessDevice.spawner(<<-'End').new("dname")
      def test_eval(str) eval(str) end
    End
    assert_equal("foo", d.call_subprocess(:test_eval, '"foo"'))
  ensure
    d.finish
  end

  def test_upcall_simple
    framework = "123456"
    d = FSEvent::ProcessDevice.spawner(<<-'End').new("dname")
      def test_eval(str) eval(str) end
    End
    d.framework = framework
    d.registered
    assert_equal(123456,
                 d.call_subprocess(:test_eval, 'call_parent(:to_i)'))
  ensure
    d.finish
  end

  def test_upcall_add_watch
    framework = Object.new
    def framework.add_watch(watchee_device_name, status_name)
      @ary ||= []
      @ary << watchee_device_name
      @ary << status_name
      nil
    end
    d = FSEvent::ProcessDevice.spawner(<<-'End').new("dname")
      def test_eval(str) eval(str) end
    End
    d.framework = framework
    d.registered
    d.call_subprocess(:test_eval, '@framework.add_watch(1,2)')
    assert_equal([1,2], framework.instance_variable_get(:@ary))
  ensure
    d.finish
  end

end
