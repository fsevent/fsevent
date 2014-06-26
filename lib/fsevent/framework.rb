# framework.rb --- fail safe event driven framework
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

class FSEvent
  include FSEvent::Util

  def initialize(initial_time=Time.now)
    @current_time = initial_time
    @current_count = 0

    @devices = {} # device_name -> device
    @device_last_run_count = {} # device_name -> count

    # special status:
    #   _fsevent : _device_registered_DEVICE_NAME       => time
    #   _fsevent : _device_unregistered_DEVICE_NAME     => time
    #   DEVICE_NAME : _status_defined_STATUS_NAME       => time
    #   DEVICE_NAME : status_undefined_STATUS_NAME      => time
    #
    @status_value = { "_fsevent" => {} } # device_name -> status_name -> value
    @status_time = { "_fsevent" => {} } # device_name -> status_name -> time
    @status_count = { "_fsevent" => {} } # device_name -> status_name -> count

    @watchset = FSEvent::WatchSet.new

    @clock_proc = nil

    @q = Depq.new
    @schedule_locator = {} # device_name -> locator
  end
  attr_reader :current_time
  attr_accessor :clock_proc

  def register_device(device, register_time=@current_time)
    device_name = device.name
    value = [:register_start, device_name, device]
    @schedule_locator[device_name] = @q.insert value, register_time
  end

  def start
    until @q.empty?
      loc = @q.delete_min_locator
      event_type, *args = loc.value
      @clock_proc.call(@current_time, loc.priority) if @clock_proc && @current_time != loc.priority
      @current_time = loc.priority
      @current_count += 1
      case event_type
      when :register_start; at_register_start(loc, *args)
      when :register_end; at_register_end(loc, *args)
      when :run_start; at_run_start(loc, *args)
      when :run_end; at_run_end(loc, *args)
      else
        raise "unexpected event type: #{event_type}"
      end
    end
  end

  def wrap_device_action(&block)
    Thread.current[:fsevent_buffer] = buffer = []
    Thread.current[:fsevent_device_elapsed_time] = nil
    t1 = Time.now
    yield
    t2 = Time.now
    elapsed = Thread.current[:fsevent_device_elapsed_time] || t2 - t1
    return buffer, elapsed
  ensure
    Thread.current[:fsevent_buffer] = nil
    Thread.current[:fsevent_device_elapsed_time] = nil
  end
  private :wrap_device_action

  # Called from a device.  (mainly from registered().)
  def add_watch(watchee_device_name_pat, status_name_pat, reaction = :immediate)
    if !valid_device_name_pat?(watchee_device_name_pat)
      raise ArgumentError, "invalid device name pattern: #{watchee_device_name_pat.inspect}"
    end
    if !valid_status_name_pat?(status_name_pat)
      raise ArgumentError, "invalid status name pattern: #{status_name_pat.inspect}"
    end
    Thread.current[:fsevent_buffer] << [:add_watch, watchee_device_name_pat, status_name_pat, reaction]
  end

  # Called from a device.  (mainly from registered().)
  def del_watch(watchee_device_name_pat, status_name_pat)
    if !valid_device_name_pat?(watchee_device_name_pat)
      raise ArgumentError, "invalid device name pattern: #{watchee_device_name_pat.inspect}"
    end
    if !valid_status_name_pat?(status_name_pat)
      raise ArgumentError, "invalid status name pattern: #{status_name_pat.inspect}"
    end
    Thread.current[:fsevent_buffer] << [:del_watch, watchee_device_name_pat, status_name_pat]
  end

  # Called from a device to define the status.
  def define_status(status_name, value)
    if !valid_status_name?(status_name)
      raise ArgumentError, "invalid status name: #{status_name.inspect}"
    end
    Thread.current[:fsevent_buffer] << [:define_status, status_name, value]
  end

  # Called from a device to notify the status.
  def status_changed(status_name, value)
    if !valid_status_name?(status_name)
      raise ArgumentError, "invalid status name: #{status_name.inspect}"
    end
    Thread.current[:fsevent_buffer] << [:status_changed, status_name, value]
  end

  # Called from a device to define the status.
  def undefine_status(status_name)
    if !valid_status_name?(status_name)
      raise ArgumentError, "invalid status name: #{status_name.inspect}"
    end
    Thread.current[:fsevent_buffer] << [:undefine_status, status_name]
  end

  # Called from a device.
  def unregister_device(device_name)
    if !valid_device_name?(device_name)
      raise ArgumentError, "invalid device name: #{device_name.inspect}"
    end
    Thread.current[:fsevent_buffer] << [:unregister_device, device_name]
  end

  # Called from a device to set the elapsed time.
  def set_elapsed_time(t)
    Thread.current[:fsevent_device_elapsed_time] = t
  end

  def at_register_start(loc, device_name, device)
    if @devices.has_key? device_name
      raise "Device already registered: #{device_name}"
    end

    buffer, elapsed = wrap_device_action {
        device.framework = self
        device.registered
    }

    value = [:register_end, device_name, device, @current_count, buffer]
    loc.update value, @current_time + elapsed
    @q.insert_locator loc
  end
  private :at_register_start

  def at_register_end(loc, device_name, device, register_start_count, buffer)
    if @devices.has_key? device_name
      raise "Device already registered: #{device_name}"
    end

    @devices[device_name] = device
    @device_last_run_count[device_name] = register_start_count
    @status_value[device_name] = {}
    @status_time[device_name] = {}
    @status_count[device_name] = {}

    internal_update_status("_fsevent", @current_time, "_device_registered_#{device_name}", @current_time)

    at_run_end(loc, device_name, register_start_count, buffer)
  end
  private :at_register_end

  def at_run_start(loc, device_name)
    time = loc.priority
    device = @devices[device_name]

    watched_status, changed_status = notifications(device_name, @device_last_run_count[device_name])

    buffer, elapsed = wrap_device_action { device.run(watched_status, changed_status) }

    value = [:run_end, device_name, @current_count, buffer]
    loc.update value, time + elapsed
    @q.insert_locator loc
  end
  private :at_run_start

  def notifications(watcher_device_name, last_run_count)
    watched_status = {}
    changed_status = {}
    @watchset.watcher_each(watcher_device_name) {|watchee_device_name_pat, status_name_pat, reaction|
      matched_device_name_each(watchee_device_name_pat) {|watchee_device_name|
        watched_status[watchee_device_name] ||= {}
        changed_status[watchee_device_name] ||= {}
        matched_status_name_each(watchee_device_name, status_name_pat) {|status_name|
          if @status_value.has_key?(watchee_device_name) &&
             @status_value[watchee_device_name].has_key?(status_name)
            watched_status[watchee_device_name][status_name] = @status_value[watchee_device_name][status_name]
          end
          if @status_time.has_key?(watchee_device_name) &&
             @status_time[watchee_device_name].has_key?(status_name) &&
             last_run_count <= @status_count[watchee_device_name][status_name]
            changed_status[watchee_device_name][status_name] = @status_time[watchee_device_name][status_name]
          end
        }
      }
    }
    return watched_status, changed_status
  end

  def at_run_end(loc, device_name, run_start_count, buffer)
    @device_last_run_count[device_name] = run_start_count
    run_end_time = loc.priority

    wakeup_immediate = false
    unregister_self = false

    buffer.each {|tag, *rest|
      case tag
      when :define_status
        internal_define_status(device_name, run_end_time, *rest)
      when :status_changed
        internal_status_changed(device_name, run_end_time, *rest)
      when :undefine_status
        internal_undefine_status(device_name, run_end_time, *rest)
      when :add_watch
        wakeup_immediate |= internal_add_watch(device_name, *rest)
      when :del_watch
        internal_del_watch(device_name, *rest)
      when :unregister_device
        unregister_self |= internal_unregister_device(device_name, *rest)
      end
    }

    unless unregister_self
      wakeup_immediate ||= immediate_wakeup_self?(device_name, run_start_count)
      setup_next_schedule(device_name, loc, run_end_time, wakeup_immediate)
    end
  end
  private :at_run_end

  def internal_define_status(device_name, run_end_time, status_name, value)
    internal_define_status2(device_name, run_end_time, status_name, value)
    internal_update_status(device_name, run_end_time, "_status_defined_#{status_name}", run_end_time)
  end
  private :internal_define_status

  def internal_update_status(device_name, run_end_time, status_name, value)
    if has_status?(device_name, status_name)
      internal_status_changed2(device_name, run_end_time, status_name, value)
    else
      internal_define_status2(device_name, run_end_time, status_name, value)
    end
  end
  private :internal_update_status

  def has_status?(device_name, status_name)
    @status_value.has_key?(device_name) && @status_value[device_name].has_key?(status_name)
  end

  def internal_define_status2(device_name, run_end_time, status_name, value)
    unless @status_value.has_key? device_name
      raise "device not defined: #{device_name}"
    end
    if @status_value[device_name].has_key? status_name
      raise "device status already defined: #{device_name} #{status_name}"
    end
    @status_value[device_name][status_name] = value
    @status_time[device_name][status_name] = @current_time
    @status_count[device_name][status_name] = @current_count
    lookup_watchers(device_name, status_name).each {|watcher_device_name, reaction|
      set_wakeup_if_possible(watcher_device_name, run_end_time) if reaction_immediate_at_beginning? reaction
    }
  end
  private :internal_define_status2

  def internal_status_changed(device_name, run_end_time, status_name, value)
    internal_status_changed2(device_name, run_end_time, status_name, value)
  end
  private :internal_status_changed

  def internal_status_changed2(device_name, run_end_time, status_name, value)
    unless @status_value.has_key? device_name
      raise "device not defined: #{device_name}"
    end
    unless @status_value[device_name].has_key? status_name
      raise "device status not defined: #{device_name} #{status_name}"
    end
    @status_value[device_name][status_name] = value
    @status_time[device_name][status_name] = @current_time
    @status_count[device_name][status_name] = @current_count
    lookup_watchers(device_name, status_name).each {|watcher_device_name, reaction|
      set_wakeup_if_possible(watcher_device_name, run_end_time) if reaction_immediate_at_subsequent? reaction
    }
  end
  private :internal_status_changed2

  def internal_undefine_status(device_name, run_end_time, status_name)
    unless @status_value.has_key? device_name
      raise "device not defined: #{device_name}"
    end
    unless @status_value[device_name].has_key? status_name
      raise "device status not defined: #{device_name} #{status_name}"
    end
    @status_value[device_name].delete status_name
    @status_time[device_name][status_name] = @current_time
    @status_count[device_name][status_name] = @current_count
    lookup_watchers(device_name, status_name).each {|watcher_device_name, reaction|
      set_wakeup_if_possible(watcher_device_name, run_end_time) if reaction_immediate_at_subsequent? reaction
    }
    internal_update_status(device_name, run_end_time, "_status_undefined_#{status_name}", run_end_time)
  end
  private :internal_define_status

  def lookup_watchers(watchee_device_name, status_name)
    @watchset.lookup_watchers(watchee_device_name, status_name)
  end
  private :lookup_watchers

  def internal_add_watch(watcher_device_name, watchee_device_name_pat, status_name_pat, reaction)
    @watchset.add(watchee_device_name_pat, status_name_pat, watcher_device_name, reaction)
    matched_status_each(watchee_device_name_pat, status_name_pat) {|watchee_device_name, status_name|
      if reaction_immediate_at_beginning? reaction
        return true
      end
    }
    false
  end
  private :internal_add_watch

  def matched_status_each(watchee_device_name_pat, status_name_pat)
    matched_device_name_each(watchee_device_name_pat) {|watchee_device_name|
      matched_status_name_each(watchee_device_name, status_name_pat) {|status_name|
        yield watchee_device_name, status_name
      }
    }
  end

  def matched_device_name_each(device_name_pat)
    if /\*\z/ =~ device_name_pat
      prefix = $`
      @devices.each {|device_name, _device|
        if device_name.start_with? prefix
          yield device_name
        end
      }
    else
      yield device_name_pat
    end
  end

  def matched_status_name_each(device_name, status_name_pat)
    return unless @status_time.has_key? device_name
    status_hash = @status_time[device_name]
    if /\*\z/ =~ status_name_pat
      prefix = $`
      status_hash.each {|status_name, _value|
        if status_name.start_with? prefix
          yield status_name
        end
      }
    else
      if status_hash.has_key? status_name_pat
        yield status_name_pat
      end
    end
  end

  def internal_del_watch(watcher_device_name, watchee_device_name_pat, status_name_pat)
    @watchset.del(watchee_device_name_pat, status_name_pat, watcher_device_name)
  end
  private :internal_del_watch

  def set_wakeup_if_possible(device_name, time)
    loc = @schedule_locator[device_name]
    if !loc.in_queue?
      loc.update [:run_start, device_name], time
      @q.insert_locator loc
      return
    end
    case event_type = loc.value.first
    when :run_start # The device is sleeping now.
      if time < loc.priority
        loc.update_priority time
      end
    when :run_end # The device is working now.
      # Nothing to do. at_run_end itself checks arrived events at last.
    else
      raise "unexpected event type: #{event_type}"
    end
  end
  private :set_wakeup_if_possible

  def setup_next_schedule(device_name, loc, run_end_time, wakeup_immediate)
    device = @devices[device_name]
    run_start_time = nil
    if wakeup_immediate
      run_start_time = run_end_time
    elsif run_start_time = device.schedule.shift
      if run_start_time < run_end_time
        run_start_time = run_end_time
      end
      while device.schedule.first && device.schedule.first < run_end_time
        device.schedule.shift
      end
    end
    if run_start_time
      value = [:run_start, device_name]
      loc.update value, run_start_time
      @q.insert_locator loc
    end
  end
  private :setup_next_schedule

  def immediate_wakeup_self?(watcher_device_name, run_start_count)
    @watchset.watcher_each(watcher_device_name) {|watchee_device_name_pat, status_name_pat, reaction|
      if reaction_immediate_at_subsequent?(reaction)
        matched_status_each(watchee_device_name_pat, status_name_pat) {|watchee_device_name, status_name|
          if @status_count.has_key?(watchee_device_name) &&
             @status_count[watchee_device_name].has_key?(status_name) &&
             run_start_count <= @status_count[watchee_device_name][status_name]
            return true
          end
        }
      end
    }
    false
  end
  private :immediate_wakeup_self?

  def internal_unregister_device(self_device_name, target_device_name)
    if @status_value.has_key? target_device_name
      @status_value[target_device_name].keys.each {|status_name|
        next if /\A_/ =~ status_name
        internal_undefine_status(target_device_name, @current_time, status_name)
      }
    end
    device = @devices.delete target_device_name
    @status_value.delete target_device_name
    @watchset.delete_watcher(target_device_name)
    loc = @schedule_locator.delete target_device_name
    if loc.in_queue?
      @q.delete_locator loc
    end
    device.unregistered
    internal_update_status("_fsevent", @current_time, "_device_unregistered_#{target_device_name}", @current_time)
    self_device_name == target_device_name
  end
  private :internal_unregister_device

end
