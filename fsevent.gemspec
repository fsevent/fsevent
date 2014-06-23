Gem::Specification.new do |s|
  s.name = 'fsevent'
  s.version = '0.1'
  s.date = '2013-06-23'
  s.author = 'Tanaka Akira'
  s.email = 'tanaka-akira@aist.go.jp'
  s.license = 'GPL-3.0+'
  s.required_ruby_version = '>= 1.9.2'
  s.add_runtime_dependency 'depq', '~> 0.6'
  s.files = %w[
    .gitignore
    LICENSE
    README.md
    fsevent.gemspec
    lib/fsevent.rb
    lib/fsevent/abstractdevice.rb
    lib/fsevent/failsafedevice.rb
    lib/fsevent/framework.rb
    lib/fsevent/periodicschedule.rb
    lib/fsevent/processdevice.rb
    lib/fsevent/processdevicec.rb
    lib/fsevent/schedulemerger.rb
    lib/fsevent/simpledevice.rb
    lib/fsevent/util.rb
    sample/repeat.rb
    sample/repeat2.rb
  ]
  s.test_files = %w[
    test/test_failsafedevice.rb
    test/test_framework.rb
    test/test_processdevice.rb
    test/test_util.rb
    test/test_watch.rb
  ]
  s.has_rdoc = true
  s.homepage = 'https://github.com/fsevent/fsevent'
  s.require_path = 'lib'
  s.summary = 'fail safe event driven framework'
  s.description = <<'End'
fail safe event driven framework
End
end


