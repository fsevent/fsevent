# test_failsafedevice.rb --- tests for fail safe device
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

class TestFSEventFailSafeDevice < Test::Unit::TestCase
  class SrcDevice < FSEvent::AbstractDevice
    def initialize(device_name, init, pairs)
      super device_name
      @init = init
      @elapsed = 1
      @schedule = pairs.map {|t, v| t-@elapsed }
      @values = pairs.map {|t, v| v }
      @test_result = []
    end
    attr_reader :test_result

    def registered
      set_elapsed_time(1)
      define_status("s", @init)
    end

    def run(watched_status, changed_status)
      @test_result << [@framework.current_time, @values.first]
      set_elapsed_time(@elapsed)
      status_changed "s", @values.shift
    end
  end

  def test_srcdevice
    t = Time.utc(2000)
    fsevent = FSEvent.new(t)
    srcdevice = SrcDevice.new("src", 0,
      [[t+10,8],
       [t+20,2],
       [t+30,3],
       [t+40,5],
       [t+50,1]])
    fsevent.register_device(srcdevice)
    fsevent.start
    assert_equal(
      [[t+9,8],
       [t+19,2],
       [t+29,3],
       [t+39,5],
       [t+49,1]],
      srcdevice.test_result)
  end

  class FailSafeDeviceT < FSEvent::FailSafeDevice
    def registered
      super
      set_elapsed_time(1)
    end

    def run(watched_status, changed_status)
      set_elapsed_time(1)
      super(watched_status, changed_status)
    end
  end

  class DstDevice < FSEvent::AbstractDevice
    def initialize(device_name, watchee_device_name, watchee_status)
      super device_name
      @watchee_device_name = watchee_device_name
      @watchee_status = watchee_status
      @test_result = []
    end
    attr_reader :test_result

    def registered
      super
      set_elapsed_time(1)
      add_watch(@watchee_device_name, @watchee_status)
    end

    def run(watched_status, changed_status)
      set_elapsed_time(1)
      @test_result << [@framework.current_time, watched_status]
    end
  end

  def test_failsafe1
    t = Time.utc(2000)
    fsevent = FSEvent.new(t)
    src1 = SrcDevice.new("src1", 0,
      [[t+10,9],
       [t+20,2],
       [t+30,3],
       [t+40,5],
       [t+50,1]])
    fsd = FailSafeDeviceT.new("fs",
      [["s", 0, lambda {|cur, val| val }]],
      "src1")
    dst = DstDevice.new("dst", "fs", "s")
    fsevent.register_device(src1)
    fsevent.register_device(fsd)
    fsevent.register_device(dst)
    fsevent.start
    assert_equal(
      [[t + 1, {"fs"=>{"s"=>0}}],
       [t + 11, {"fs"=>{"s"=>9}}],
       [t + 21, {"fs"=>{"s"=>2}}],
       [t + 31, {"fs"=>{"s"=>3}}],
       [t + 41, {"fs"=>{"s"=>5}}],
       [t + 51, {"fs"=>{"s"=>1}}]],
      dst.test_result)
  end

  def test_failsafe2_max
    t = Time.utc(2000)
    fsevent = FSEvent.new(t)
    src1 = SrcDevice.new("src1", 0,
      [[t+10,9],
       [t+20,2],
       [t+30,3],
       [t+40,5],
       [t+50,1]])
    src2 = SrcDevice.new("src2", 0,
      [[t+11,9],
       [t+19,2],
       [t+31,3],
       [t+39,5],
       [t+51,1]])
    fsd = FailSafeDeviceT.new("fs",
      [["s", 0, :max]],
      "src1", "src2")
    dst = DstDevice.new("dst", "fs", "s")
    fsevent.register_device(src1)
    fsevent.register_device(src2)
    fsevent.register_device(fsd)
    fsevent.register_device(dst)
    fsevent.start
    assert_equal(
      [[t + 1, {"fs"=>{"s"=>0}}],
       [t + 10+1, {"fs"=>{"s"=>9}}],
       [t + 20+1, {"fs"=>{"s"=>2}}],
       [t + 30+1, {"fs"=>{"s"=>3}}],
       [t + 39+1, {"fs"=>{"s"=>5}}],
       [t + 51+1, {"fs"=>{"s"=>1}}]],
      dst.test_result)
  end

end
