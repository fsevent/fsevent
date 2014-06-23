# test_util.rb --- tests for util.rb
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

class TestFSEventUtil < Test::Unit::TestCase
  def test_nested_hash_level1
    h = FSEvent::Util.nested_hash(1)
    assert_equal(0, h.size)
    assert_equal(nil, h[:k])
    assert_equal(0, h.size)
  end

  def test_nested_hash_level2
    h = FSEvent::Util.nested_hash(2)
    assert_equal(0, h.size)
    h2 = h[:k1]
    assert_equal({}, h2)
    assert_same(h2, h[:k1])
    assert_equal(1, h.size)
    assert_equal(nil, h[:k1][:k2])
    assert_equal(0, h2.size)
  end

  def test_nested_hash_level3
    h = FSEvent::Util.nested_hash(3)
    assert_equal(0, h.size)
    h2 = h[:k1]
    assert_equal({}, h2)
    assert_same(h2, h[:k1])
    assert_equal(1, h.size)
    h3 = h[:k1][:k2]
    assert_equal({}, h3)
    assert_same(h3, h[:k1][:k2])
    assert_equal(1, h2.size)
  end

end
