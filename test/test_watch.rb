# test_watch.rb --- tests for watching device status
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

class TestFSEventWatch < Test::Unit::TestCase
  def test_srcdevice
    t = Time.utc(2000)
    fsevent = FSEvent.new(t)
    values = [9,2,3,5,1]
    src_sched = values.map.with_index {|v, i| t + (i+1)*10 }
    srcdevice = FSEvent::SimpleDevice.new("src", {"s"=>0}, [], 1, src_sched) {
      |watched_status, changed_status|
      fsevent.set_elapsed_time(5)
      fsevent.status_changed "s", values.shift
    }
    fsevent.register_device(srcdevice)
    fsevent.start
    assert_equal([], values)
  end

  def test_watch_register_order
    2.times {|i|
      t = Time.utc(2000)
      fsevent = FSEvent.new(t)
      values = [9,2,3,5,1]
      src_sched = values.map.with_index {|v, j| t + (j+1)*10 }
      srcdevice = FSEvent::SimpleDevice.new("src", {"s"=>0}, [], 1, src_sched) {
        |watched_status, changed_status|
        fsevent.set_elapsed_time(5)
        fsevent.status_changed "s", values.shift
      }
      test_result = []
      dstdevice = FSEvent::SimpleDevice.new("dst", {}, [["src","s"]], 1) {
        |watched_status, changed_status|
        fsevent.set_elapsed_time(1)
        test_result << [fsevent.current_time, watched_status]
      }
      if i == 0
        fsevent.register_device(srcdevice)
        fsevent.register_device(dstdevice)
      else
        fsevent.register_device(dstdevice)
        fsevent.register_device(srcdevice)
      end
      fsevent.start
      assert_equal(
        [[t + 1,      {"src"=>{"s"=>0}}],
         [t + 10*1+5, {"src"=>{"s"=>9}}],
         [t + 10*2+5, {"src"=>{"s"=>2}}],
         [t + 10*3+5, {"src"=>{"s"=>3}}],
         [t + 10*4+5, {"src"=>{"s"=>5}}],
         [t + 10*5+5, {"src"=>{"s"=>1}}]],
        test_result)
    }
  end

  def test_wakeup_immediate
    t = Time.utc(2000)
    fsevent = FSEvent.new(t)
    srcdevice = FSEvent::SimpleDevice.new("src", {"s"=>0}, [], 1, [t+10]) {
      |watched_status, changed_status|
      fsevent.set_elapsed_time(5)
      fsevent.status_changed "s", 100
    }
    test_result = []
    dstdevice = FSEvent::SimpleDevice.new("dst", {}, [["src","s", :immediate]], 1, [t+20]) {
      |watched_status, changed_status|
      fsevent.set_elapsed_time(1)
      test_result << [fsevent.current_time, watched_status]
    }
    fsevent.register_device(srcdevice)
    fsevent.register_device(dstdevice)
    fsevent.start
    assert_equal(
      [[t + 1, {"src"=>{"s"=>0}}],
       [t + 15, {"src"=>{"s"=>100}}]],
      test_result)
  end

  def test_wakeup_immediate_only_at_beginning
    t = Time.utc(2000)
    fsevent = FSEvent.new(t)
    srcdevice = FSEvent::SimpleDevice.new("src", {"s"=>0}, [], 1, [t+10]) {
      |watched_status, changed_status|
      fsevent.set_elapsed_time(5)
      fsevent.status_changed "s", 100
    }
    test_result = []
    dstdevice = FSEvent::SimpleDevice.new("dst", {}, [["src","s", :immediate_only_at_beginning]], 1, [t+20]) {
      |watched_status, changed_status|
      fsevent.set_elapsed_time(1)
      test_result << [fsevent.current_time, watched_status]
    }
    fsevent.register_device(srcdevice)
    fsevent.register_device(dstdevice)
    fsevent.start
    assert_equal(
      [[t + 1, {"src"=>{"s"=>0}}],
       [t + 20, {"src"=>{"s"=>100}}]],
      test_result)
  end

  def test_wakeup_schedule
    t = Time.utc(2000)
    fsevent = FSEvent.new(t)
    srcdevice = FSEvent::SimpleDevice.new("src", {"s"=>0}, [], 1, [t+10]) {
      |watched_status, changed_status|
      fsevent.set_elapsed_time(5)
      fsevent.status_changed "s", 100
    }
    test_result = []
    dstdevice = FSEvent::SimpleDevice.new("dst", {}, [["src","s", :schedule]], 1, [t+20]) {
      |watched_status, changed_status|
      fsevent.set_elapsed_time(1)
      test_result << [fsevent.current_time, watched_status]
    }
    fsevent.register_device(srcdevice)
    fsevent.register_device(dstdevice)
    fsevent.start
    assert_equal(
      [[t + 20, {"src"=>{"s"=>100}}]],
      test_result)
  end

  def test_unwatch
    t = Time.utc(2000)
    fsevent = FSEvent.new(t)
    s = 0
    srcdevice = FSEvent::SimpleDevice.new("src", {"s"=>0}, [], 1, [t+10, t+20]) {
      |watched_status, changed_status|
      fsevent.set_elapsed_time(5)
      s += 100
      fsevent.status_changed "s", s
    }
    test_result = []
    dstdevice = FSEvent::SimpleDevice.new("dst", {}, [["src","s", :schedule]], 1, [t+17, t+27]) {
      |watched_status, changed_status|
      fsevent.set_elapsed_time(1)
      if fsevent.current_time == t+17
        fsevent.del_watch("src", "s")
      end
      test_result << [fsevent.current_time, watched_status]
    }
    fsevent.register_device(srcdevice)
    fsevent.register_device(dstdevice)
    fsevent.start
    assert_equal(
      [[t+17, {"src"=>{"s"=>100}}],
       [t+27, {}]],
      test_result)
  end

  def test_lookup_watchers_exact1
    ws = FSEvent::WatchSet.new
    ws.add("src", "status", "d", :immediate)
    assert_equal([["d", :immediate]], ws.lookup_watchers("src", "status"))
  end

  def test_lookup_watchers_exact2
    ws = FSEvent::WatchSet.new
    ws.add("src", "s", "d1", :immediate)
    ws.add("src", "s", "d2", :schedule)
    assert_equal([["d1", :immediate], ["d2", :schedule]],
                 ws.lookup_watchers("src", "s"))
  end

  def test_lookup_watchers_prefix_exact
    ws = FSEvent::WatchSet.new
    ws.add("sr*", "status", "d", :immediate)
    assert_equal([["d", :immediate]], ws.lookup_watchers("src", "status"))
  end

  def test_lookup_watchers_exact_prefix
    ws = FSEvent::WatchSet.new
    ws.add("src", "st*", "d", :immediate)
    assert_equal([["d", :immediate]], ws.lookup_watchers("src", "status"))
  end

  def test_lookup_watchers_prefix_prefix
    ws = FSEvent::WatchSet.new
    ws.add("sr*", "st*", "d", :immediate)
    assert_equal([["d", :immediate]], ws.lookup_watchers("src", "status"))
  end

end
