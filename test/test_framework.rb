# test_framework.rb --- test for framework.rb
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

class TestFSEventFramework < Test::Unit::TestCase

  class TDevice < FSEvent::AbstractDevice
    attr_accessor :test_result
    def initialize(device_name)
      super
      @test_result = []
    end
  end

  def test_nodevice
    fsevent = FSEvent.new
    assert_nothing_raised { fsevent.start }
  end

  def test_inactive_device
    fsevent = FSEvent.new
    device = FSEvent::AbstractDevice.new("test_inactive_device")
    fsevent.register_device device
    assert_nothing_raised { fsevent.start }
  end

  def test_single_run
    t0 = Time.utc(2000)
    t1 = Time.utc(2001)
    fsevent = FSEvent.new(t0)
    device = TDevice.new("test_single_run")
    device.schedule.merge_schedule([t1])
    def device.run(watched_status, changed_status)
      @test_result << @framework.current_time
      @test_result << watched_status
    end
    fsevent.register_device(device)
    assert_nothing_raised { fsevent.start }
    assert_equal([t1, {}], device.test_result)
  end

  def test_double_run
    t0 = Time.utc(2000)
    t1 = Time.utc(2001)
    t2 = Time.utc(2002)
    fsevent = FSEvent.new(t0)
    device = TDevice.new("test_double_run")
    device.schedule.merge_schedule([t1, t2])
    def device.run(watched_status, changed_status)
      @test_result << @framework.current_time
      @test_result << watched_status
    end
    fsevent.register_device(device)
    assert_nothing_raised { fsevent.start }
    assert_equal([t1, {}, t2, {}], device.test_result)
  end

  def test_repeated_run
    t0 = Time.utc(2000)
    t1 = Time.utc(2001)
    fsevent = FSEvent.new(t0)
    device = TDevice.new("test_repeated_run")
    schedule = FSEvent::PeriodicSchedule.new(t1, 3)
    device.schedule.merge_schedule(schedule)
    def device.run(watched_status, changed_status)
      @test_result << @framework.current_time
      @schedule.clear if 2 < @test_result.length
    end
    fsevent.register_device(device)
    assert_nothing_raised { fsevent.start }
    assert_equal([t1, t1+3, t1+6], device.test_result)
  end

  def test_twodevice
    t0 = Time.utc(2000)
    t1 = Time.utc(2001)
    t2 = Time.utc(2002)
    fsevent = FSEvent.new(t0)
    device1 = TDevice.new("test_twodevice_1")
    device1.schedule.merge_schedule([t1])
    def device1.run(watched_status, changed_status)
      @test_result << @framework.current_time
    end
    device2 = TDevice.new("test_twodevice_2")
    device2.schedule.merge_schedule([t2])
    def device2.run(watched_status, changed_status)
      @test_result << @framework.current_time
    end
    fsevent.register_device(device1)
    fsevent.register_device(device2)
    assert_nothing_raised { fsevent.start }
    assert_equal([t1], device1.test_result)
    assert_equal([t2], device2.test_result)
  end

  def test_negative_elapsed_time
    t = Time.utc(2000)
    fse = FSEvent.new(t)
    d = FSEvent::AbstractDevice.new("d")
    def d.registered
      set_elapsed_time(-1)
    end
    fse.register_device d
    assert_raise(ArgumentError) { fse.start }
  end

  def test_undefine_status
    t = Time.utc(2000)
    fse = FSEvent.new(t)
    d1 = FSEvent::SimpleDevice.new("d1", {"s"=>0}, [], 5, [t+10]) {|watched_status, changed_status|
      fse.undefine_status("s")
      fse.set_elapsed_time(1)
    }
    result = []
    d2 = FSEvent::SimpleDevice.new("d2", {}, [["d1", "s", :immediate]], 1) {|watched_status, changed_status|
      result << [fse.current_time, watched_status, changed_status]
      fse.set_elapsed_time(1)
    }
    fse.register_device d1
    fse.register_device d2
    fse.start
    assert_equal(
      [[t+5, {"d1"=>{"s"=>0}}, {"d1"=>{"s"=>t+5}}],
       [t+11, {"d1"=>{}}, {"d1"=>{"s"=>t+11}}]],
       result)
  end

  def test_unregister_in_sleeping
    t0 = Time.utc(2000)
    fsevent = FSEvent.new(t0)
    sched1 = FSEvent::PeriodicSchedule.new(t0+10,5)
    result = []
    device1 = FSEvent::SimpleDevice.new("target", {}, [], 1, sched1) {
      |watched_status, changed_status|
      result << fsevent.current_time
      fsevent.set_elapsed_time(2)
    }
    device2 = FSEvent::SimpleDevice.new("dev", {}, [], 1, [t0+23]) {
      fsevent.unregister_device("target")
    }
    fsevent.register_device device1
    fsevent.register_device device2
    fsevent.start
    assert_equal([t0+10,t0+15,t0+20], result)
  end

  def test_unregister_in_working
    t0 = Time.utc(2000)
    fsevent = FSEvent.new(t0)
    sched1 = FSEvent::PeriodicSchedule.new(t0+10,5)
    result = []
    device1 = FSEvent::SimpleDevice.new("target", {}, [], 1, sched1) {
      |watched_status, changed_status|
      result << fsevent.current_time
      fsevent.set_elapsed_time(2)
    }
    device2 = FSEvent::SimpleDevice.new("dev", {}, [], 1, [t0+21]) {
      fsevent.unregister_device("target")
    }
    fsevent.register_device device1
    fsevent.register_device device2
    fsevent.start
    assert_equal([t0+10,t0+15,t0+20], result)
  end

  def test_unregister_self
    t0 = Time.utc(2000)
    fsevent = FSEvent.new(t0)
    sched1 = FSEvent::PeriodicSchedule.new(t0+10,5)
    result = []
    device1 = FSEvent::SimpleDevice.new("target", {}, [], 1, sched1) {
      |watched_status, changed_status|
      result << fsevent.current_time
      if fsevent.current_time == t0+20
        fsevent.unregister_device("target")
      end
      fsevent.set_elapsed_time(2)
    }
    fsevent.register_device device1
    fsevent.start
    assert_equal([t0+10,t0+15,t0+20], result)
  end

  def test_unregister_time
    t = Time.utc(2000)
    fse = FSEvent.new(t)
    d1 = FSEvent::SimpleDevice.new("d1", {"s"=>0}, [], 5, [t+10]) {|watched_status, changed_status|
      fse.unregister_device("d1")
      fse.set_elapsed_time(1)
    }
    result = []
    d2 = FSEvent::SimpleDevice.new("d2", {}, [["d1", "s", :immediate]], 1) {|watched_status, changed_status|
      result << [fse.current_time, watched_status, changed_status]
      fse.set_elapsed_time(1)
    }
    fse.register_device d1
    fse.register_device d2
    fse.start
    assert_equal(
      [[t+5, {"d1"=>{"s"=>0}}, {"d1"=>{"s"=>t+5}}],
       [t+11, {"d1"=>{}}, {"d1"=>{"s"=>t+11}}]],
       result)
  end

  def test_clock_proc
    t = Time.utc(2000)
    fse = FSEvent.new(t)
    d = FSEvent::SimpleDevice.new("d1", {"s"=>0}, [], 5, [t+20, t+32]) {|watched_status, changed_status|
      fse.set_elapsed_time(1)
    }
    fse.register_device d
    result = []
    fse.clock_proc = lambda {|current_time, next_time|
      result << next_time - current_time
    }
    fse.start
    assert_equal([5, 15, 1, 11, 1], result)
  end

  def test_device_registered1
    t = Time.utc(2000)
    fse = FSEvent.new(t)
    #fse.register_device FSEvent::DebugDumper.new
    d11 = FSEvent::SimpleDevice.new("d1", {}, [], 1, [t+19, t+29, t+39, t+49]) {|watched_status, changed_status|
      case fse.current_time
      when t+10
      when t+19
        fse.define_status("s", 100)
      when t+29
        fse.undefine_status("s")
      when t+39
        fse.define_status("s", 200)
      when t+49
        fse.unregister_device("d1")
      else
        raise "unexpected time"
      end
      fse.set_elapsed_time(1)
    }
    d12 = FSEvent::SimpleDevice.new("d1", {}, [], 1, []) {|watched_status, changed_status|
      fse.set_elapsed_time(1)
    }
    d0 = FSEvent::SimpleDevice.new("d0", {}, [], 1, [t+9, t+59]) {|watched_status, changed_status|
      fse.set_elapsed_time(1)
      case fse.current_time
      when t+9
        fse.register_device d11
      when t+59
        fse.register_device d12
      else
        raise "unexpected wakeup d0"
      end
    }
    times = []
    d2 = FSEvent::SimpleDevice.new("d2", {},
                                   [["_fsevent", "_device_registered_d1", :immediate],
                                    ["_fsevent", "_device_unregistered_d1", :immediate],
                                    ["d1", "_status_defined_s", :immediate],
                                    ["d1", "_status_undefined_s", :immediate],
                                    ["d1", "s", :immediate]],
                                   1, [t+5]) {|watched_status, changed_status|
      case fse.current_time
      when t+5
        assert_equal({"_fsevent"=>{}, "d1"=>{}}, watched_status)
        assert_equal({"_fsevent"=>{}, "d1"=>{}}, changed_status)
      when t+11
        assert_equal({"_fsevent"=>{"_device_registered_d1"=>t+11}, "d1"=>{}}, watched_status)
        assert_equal({"_fsevent"=>{"_device_registered_d1"=>t+11}, "d1"=>{}}, changed_status)
      when t+20
        assert_equal({"_fsevent"=>{"_device_registered_d1"=>t+11}, "d1"=>{"s"=>100, "_status_defined_s"=>t+20}}, watched_status)
        assert_equal({"_fsevent"=>{}, "d1"=>{"s"=>t+20, "_status_defined_s"=>t+20}}, changed_status)
      when t+30
        assert_equal({"_fsevent"=>{"_device_registered_d1"=>t+11}, "d1"=>{"_status_defined_s"=>t+20, "_status_undefined_s"=>t+30}}, watched_status)
        assert_equal({"_fsevent"=>{}, "d1"=>{"s"=>t+30, "_status_undefined_s"=>t+30}}, changed_status)
      when t+40
        assert_equal({"_fsevent"=>{"_device_registered_d1"=>t+11}, "d1"=>{"s"=>200, "_status_defined_s"=>t+40, "_status_undefined_s"=>t+30}}, watched_status)
        assert_equal({"_fsevent"=>{}, "d1"=>{"s"=>t+40, "_status_defined_s"=>t+40}}, changed_status)
      when t+50
        assert_equal({"_fsevent"=>{"_device_registered_d1"=>t+11, "_device_unregistered_d1"=>t+50}, "d1"=>{}}, watched_status)
        assert_equal({"_fsevent"=>{"_device_unregistered_d1"=>t+50}, "d1"=>{"s"=>t+50, "_status_undefined_s"=>t+50}}, changed_status)
      when t+61
        assert_equal({"_fsevent"=>{"_device_registered_d1"=>t+61, "_device_unregistered_d1"=>t+50}, "d1"=>{}}, watched_status)
        assert_equal({"_fsevent"=>{"_device_registered_d1"=>t+61}, "d1"=>{}}, changed_status)
      else
        raise "unexpected wakeup d2 #{fse.current_time}"
      end
      times << fse.current_time
      fse.set_elapsed_time(1)
    }
    fse.register_device d0
    fse.register_device d2
    fse.start
    assert_equal([t+5, t+11, t+20, t+30, t+40, t+50, t+61], times)
  end

  def test_valid_name_for_write
    t = Time.utc(2000)
    fse = FSEvent.new(t)
    assert_raise(ArgumentError) {
      d = FSEvent::AbstractDevice.new("_d")
      fse.register_device(d)
    }
    assert_raise(ArgumentError) { fse.define_status("_s", 0) }
    assert_raise(ArgumentError) { fse.modify_status("_s", 0) }
    assert_raise(ArgumentError) { fse.undefine_status("_s") }
    assert_raise(ArgumentError) { fse.unregister_device("_d") }

  end

  def test_register_time
    t = Time.utc(2000)
    fse = FSEvent.new(t)
    result = []
    d1 = FSEvent::SimpleDevice.new("d1", {}, [], 1, [t+10]) {|watched_status, changed_status|
      fse.set_elapsed_time(10)
      d2 = FSEvent::AbstractDevice.new("d2")
      class << d2; self end.send(:define_method, :registered) {
        result << fse.current_time
      }
      fse.register_device(d2)
    }
    fse.register_device d1
    fse.start
    assert_equal([t+20], result)
  end

  def test_too_long_run
    t = Time.utc(2000)
    fse = FSEvent.new(t)
    result = []
    d1 = FSEvent::SimpleDevice.new("d2", {}, [], 1, [t+10, t+20, t+30]) {|watched_status, changed_status|
      fse.set_elapsed_time(15)
      result << fse.current_time
    }
    fse.register_device d1
    fse.start
    assert_equal([t+10, t+25, t+40], result)
  end

  def test_too_long_run_2
    t = Time.utc(2000)
    fse = FSEvent.new(t)
    result = []
    d1 = FSEvent::SimpleDevice.new("d2", {}, [], 1, [t+10, t+20, t+30]) {|watched_status, changed_status|
      fse.set_elapsed_time(25)
      result << fse.current_time
    }
    fse.register_device d1
    fse.start
    assert_equal([t+10, t+35], result)
  end

  def test_frequent_immediate_event
    t = Time.utc(2000)
    fse = FSEvent.new(t)
    n = 0
    d1 = FSEvent::SimpleDevice.new("d1", {"s"=>n}, [], 1, [t+11,t+12,t+13,t+14]) {|watched_status, changed_status|
      n += 1
      fse.modify_status("s", n)
      fse.set_elapsed_time(0)
    }
    result = []
    d2 = FSEvent::SimpleDevice.new("d2", {}, [["d1", "s", :immediate]], 1, [t+10, t+20]) {|watched_status, changed_status|
      fse.set_elapsed_time(5)
      result << fse.current_time
    }
    fse.register_device d1
    fse.register_device d2
    fse.start
    p result
    #assert_equal([t+20], result)
  end

end
