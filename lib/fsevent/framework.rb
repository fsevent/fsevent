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
    @device_last_run = {} # device_name -> time
    @device_last_run_count = {} # device_name -> count

    @status_value = {} # device_name -> status_name -> value

    # special status names: _device_registered, _device_unregistered, _status_NAME_defined, _status_NAME_undefined
    @status_time = {} # device_name -> status_name -> time
    @status_count = {} # device_name -> status_name -> count

    # valid values of reaction: :immediate, :immediate_only_at_beginning, :schedule
    @watch_defs = nested_hash(3) # watcher_device_name -> watchee_device_name -> status_name -> reaction
    @watch_reactions = nested_hash(3) # watchee_device_name -> status_name -> watcher_device_name -> reaction

    @q = Depq.new
    @schedule_locator = {} # device_name -> locator
  end
  attr_reader :current_time

  def register_device(device, register_time=@current_time)
    device_name = device.name
    value = [:register, device_name, device]
    @schedule_locator[device_name] = @q.insert value, register_time
  end

  def start
    until @q.empty?
      loc = @q.delete_min_locator
      event_type, *args = loc.value
      @current_time = loc.priority
      @current_count += 1
      case event_type
      when :register; at_register(loc, *args)
      when :register_end; at_register_end(loc, *args)
      when :wakeup; at_wakeup(loc, *args)
      when :sleep; at_sleep(loc, *args)
      else
        raise "unexpected event type: #{event_type}"
      end
    end
  end

  def wrap_device_action(&block)
    Thread.current[:fsevent_device_watch_buffer] = device_watch_buffer = []
    Thread.current[:fsevent_device_define_buffer] = device_define_buffer = []
    Thread.current[:fsevent_device_changed_buffer] = device_changed_buffer = []
    Thread.current[:fsevent_unregister_device_buffer] = unregister_device_buffer = []
    Thread.current[:fsevent_device_elapsed_time] = nil
    t1 = Time.now
    yield
    t2 = Time.now
    elapsed = Thread.current[:fsevent_device_elapsed_time] || t2 - t1
    return device_watch_buffer, device_define_buffer, device_changed_buffer, unregister_device_buffer, elapsed
  ensure
    Thread.current[:fsevent_device_watch_buffer] = nil
    Thread.current[:fsevent_device_define_buffer] = nil
    Thread.current[:fsevent_device_changed_buffer] = nil
    Thread.current[:fsevent_unregister_device_buffer] = nil
    Thread.current[:fsevent_device_elapsed_time] = nil
  end
  private :wrap_device_action

  # Called from a device.  (mainly from registered().)
  def add_watch(watchee_device_name, status_name, reaction = :immediate)
    Thread.current[:fsevent_device_watch_buffer] << [:add, watchee_device_name, status_name, reaction]
  end

  # Called from a device.  (mainly from registered().)
  def del_watch(watchee_device_name, status_name)
    Thread.current[:fsevent_device_watch_buffer] << [:del, watchee_device_name, status_name, nil]
  end

  # Called from a device to define the status.
  def define_status(status_name, value)
    Thread.current[:fsevent_device_define_buffer] << [status_name, value]
  end

  # Called from a device to notify the status.
  def status_changed(status_name, value)
    Thread.current[:fsevent_device_changed_buffer] << [status_name, value]
  end

  # Called from a device.
  def unregister_device(device_name)
    Thread.current[:fsevent_unregister_device_buffer] << device_name
  end

  # Called from a device to set the elapsed time.
  def set_elapsed_time(t)
    raise "elapsed time must be positive: #{t}" if t <= 0
    Thread.current[:fsevent_device_elapsed_time] = t
  end

  def at_register(loc, device_name, device)
    if @devices.has_key? device_name
      raise "Device already registered: #{device_name}"
    end

    device_watch_buffer, device_define_buffer, device_changed_buffer, unregister_device_buffer, elapsed =
      wrap_device_action {
        device.framework = self
        device.registered
    }

    value = [:register_end, device_name, device, @current_time, @current_count, device_watch_buffer, device_define_buffer, device_changed_buffer, unregister_device_buffer]
    loc.update value, @current_time + elapsed
    @q.insert_locator loc
  end
  private :at_register

  def at_register_end(loc, device_name, device, register_time, register_count, device_watch_buffer, device_define_buffer, device_changed_buffer, unregister_device_buffer)
    if @devices.has_key? device_name
      raise "Device already registered: #{device_name}"
    end

    @devices[device_name] = device
    @device_last_run[device_name] = register_time
    @device_last_run_count[device_name] = register_count
    @status_value[device_name] = {}
    @status_time[device_name] = {}
    @status_count[device_name] = {}

    at_sleep(loc, device_name, register_time, register_count, device_watch_buffer, device_define_buffer, device_changed_buffer, unregister_device_buffer)
  end
  private :at_register_end

  def at_wakeup(loc, device_name)
    time = loc.priority
    device = @devices[device_name]

    watched_status, changed_status = notifications(device_name, @device_last_run[device_name], @device_last_run_count[device_name])

    device_watch_buffer, device_define_buffer, device_changed_buffer, unregister_device_buffer, elapsed =
      wrap_device_action { device.run(watched_status, changed_status) }

    @device_last_run[device_name] = time
    @device_last_run_count[device_name] = @current_count
    value = [:sleep, device_name, time, @current_count, device_watch_buffer, device_define_buffer, device_changed_buffer, unregister_device_buffer]
    loc.update value, time + elapsed
    @q.insert_locator loc
  end
  private :at_wakeup

  def notifications(device_name, last_run, last_run_count)
    watched_status = {}
    changed_status = {}
    if @watch_defs.has_key? device_name
      @watch_defs[device_name].each {|watchee_device_name_pat, h|
        h.each {|status_name_pat, _reaction|
          matched_device_name_each(watchee_device_name_pat) {|watchee_device_name|
            matched_status_name_each(watchee_device_name, status_name_pat) {|status_name|
              if @status_value.has_key?(watchee_device_name) &&
                 @status_value[watchee_device_name].has_key?(status_name)
                watched_status[watchee_device_name] ||= {}
                watched_status[watchee_device_name][status_name] = @status_value[watchee_device_name][status_name]
              end
              if @status_time.has_key?(watchee_device_name) &&
                 @status_time[watchee_device_name].has_key?(status_name) &&
                 last_run_count <= @status_count[watchee_device_name][status_name]
                changed_status[watchee_device_name] ||= {}
                changed_status[watchee_device_name][status_name] = @status_time[watchee_device_name][status_name]
              end
            }
          }
        }
      }
    end

    return watched_status, changed_status
  end

  def at_sleep(loc, device_name, wakeup_time, wakeup_count, device_watch_buffer, device_define_buffer, device_changed_buffer, unregister_device_buffer)
    sleep_time = loc.priority
    update_status(device_name, device_define_buffer, device_changed_buffer)
    wakeup_immediate = update_watch(device_name, device_watch_buffer)
    notify_status_change(device_name, sleep_time, device_define_buffer, device_changed_buffer)
    wakeup_immediate ||= immediate_wakeup?(device_name, wakeup_time, wakeup_count)
    setup_next_schedule(device_name, loc, sleep_time, wakeup_immediate)
    unregister_device_internal(unregister_device_buffer)
  end
  private :at_sleep

  def update_status(device_name, device_define_buffer, device_changed_buffer)
    unless @status_value.has_key? device_name
      raise "device not defined: #{device_name}"
    end
    device_define_buffer.each {|status_name, value|
      if @status_value[device_name].has_key? status_name
        raise "device status already defined: #{device_name} #{status_name}"
      end
      @status_value[device_name][status_name] = value
      @status_time[device_name][status_name] = @current_time
      @status_time[device_name]["_status_#{status_name}_defined"] = @current_time
      @status_count[device_name][status_name] = @current_count
      @status_count[device_name]["_status_#{status_name}_defined"] = @current_count
    }
    device_changed_buffer.each {|status_name, value|
      unless @status_value[device_name].has_key? status_name
        raise "device status not defined: #{device_name} #{status_name}"
      end
      @status_value[device_name][status_name] = value
      @status_time[device_name][status_name] = @current_time
      @status_count[device_name][status_name] = @current_count
    }
  end
  private :update_status

  def update_watch(device_name, device_watch_buffer)
    wakeup_immediate = false
    device_watch_buffer.each {|add_or_del, watchee_device_name, status_name, reaction|
      case add_or_del
      when :add
        wakeup_immediate = add_watch_internal(watchee_device_name, status_name, device_name, reaction)
      when :del
        del_watch_internal(watchee_device_name, status_name, device_name)
      else
        raise "unexpected add_or_del: #{add_or_del.inspect}"
      end
    }
    wakeup_immediate
  end
  private :update_watch

  def add_watch_internal(watchee_device_name, status_name, watcher_device_name, reaction)
    @watch_defs[watcher_device_name][watchee_device_name][status_name] = reaction
    @watch_reactions[watchee_device_name][status_name][watcher_device_name] = reaction
    wakeup_immediate = false
    catch(:catch_add_watch_internal) {|tag|
      matched_device_name_each(watchee_device_name) {|watchee_dn|
        matched_status_name_each(watchee_dn, status_name) {|sn|
          wakeup_immediate = reaction_immediate_at_beginning? reaction
          throw tag
        }
      }
    }
    wakeup_immediate
  end
  private :add_watch_internal

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
    #xxx: special status names: _device_registered, _device_unregistered, _status_NAME_defined, _status_NAME_undefined
    return unless @status_value.has_key? device_name
    status_hash = @status_value[device_name]
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

  def del_watch_internal(watchee_device_name, status_name, watcher_device_name)
    @watch_defs[watcher_device_name][watchee_device_name].delete status_name
    @watch_reactions[watchee_device_name][status_name].delete watcher_device_name
  end
  private :del_watch_internal

  def notify_status_change(device_name, sleep_time, device_define_buffer, device_changed_buffer)
    device_define_buffer.each {|status_name, _|
      value = @status_value[device_name][status_name]
      lookup_watchers(device_name, status_name).each {|watcher_device_name, reaction|
        set_wakeup_if_possible(watcher_device_name, sleep_time) if reaction_immediate_at_beginning? reaction
      }
    }
    device_changed_buffer.each {|status_name, _|
      value = @status_value[device_name][status_name]
      lookup_watchers(device_name, status_name).each {|watcher_device_name, reaction|
        set_wakeup_if_possible(watcher_device_name, sleep_time) if reaction_immediate_at_subsequent? reaction
      }
    }
  end
  private :notify_status_change

  def lookup_watchers(watchee_device_name, status_name)
    result = []
    if @watch_reactions.has_key?(watchee_device_name) &&
       @watch_reactions[watchee_device_name].has_key?(status_name)
      @watch_reactions[watchee_device_name][status_name].each {|watcher_device_name, reaction|
        result << [watcher_device_name, reaction]
      }
    end
    result
  end
  private :lookup_watchers

  def set_wakeup_if_possible(device_name, time)
    loc = @schedule_locator[device_name]
    if !loc.in_queue?
      loc.update [:wakeup, device_name], time
      @q.insert_locator loc
      return
    end
    case event_type = loc.value.first
    when :wakeup # The device is sleeping now.
      if time < loc.priority
        loc.update_priority time
      end
    when :sleep # The device is working now.
      # Nothing to do. at_sleep itself checks arrived events at last.
    else
      raise "unexpected event type: #{event_type}"
    end
  end
  private :set_wakeup_if_possible

  def setup_next_schedule(device_name, loc, sleep_time, wakeup_immediate)
    device = @devices[device_name]
    wakeup_time = nil
    if wakeup_immediate
      wakeup_time = sleep_time
    elsif wakeup_time = device.schedule.shift
      if wakeup_time < sleep_time
        wakeup_time = sleep_time
      end
      while device.schedule.first && device.schedule.first < sleep_time
        device.schedule.shift
      end
    end
    if wakeup_time
      value = [:wakeup, device_name]
      loc.update value, wakeup_time
      @q.insert_locator loc
    end
  end
  private :setup_next_schedule

  def immediate_wakeup?(watcher_device_name, wakeup_time, wakeup_count)
    wakeup_immediate = false
    @watch_defs[watcher_device_name].each {|watchee_device_name_pat, h|
      h.each {|status_name_pat, reaction|
        if reaction_immediate_at_subsequent?(reaction)
          matched_device_name_each(watchee_device_name_pat) {|watchee_device_name|
            matched_status_name_each(watchee_device_name, status_name_pat) {|status_name|
              if @status_time.has_key?(watchee_device_name) &&
                 @status_time[watchee_device_name].has_key?(status_name) &&
                 wakeup_count <= @status_count[watchee_device_name][status_name]
                wakeup_immediate = true
              end
            }
          }
        end
      }
    }
    wakeup_immediate
  end
  private :immediate_wakeup?

  def unregister_device_internal(unregister_device_buffer)
    unregister_device_buffer.each {|device_name|
      #device = @devices.delete device_name
      #@status_value.delete device_name
      #@watch_defs.delete device_name
      #@watch_reactions.each {|watchee_device_name, h1|
      #  h1.each {|status_name, h2|
      #    h2.delete device_name
      #  }
      #}
      #loc = @schedule_locator.fetch(device_name)
      #device.unregistered
      #@q.delete_locator loc
    }

    unregister_device_buffer.each {|device_name|
      device = @devices.delete device_name
      @status_value.delete device_name
      loc = @schedule_locator.fetch(device_name)
      device.unregistered
      @q.delete_locator loc
    }

  end
  private :unregister_device_internal

end
