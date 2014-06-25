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
      @schedule = [] if 2 < @test_result.length
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

end
