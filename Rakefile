require 'rake'
require 'rake/gempackagetask'
require 'rake/testtask'
require 'rake/clean'

PKG_NAME = 'rmplayer'
PKG_VERSION = "1.0"

PKG_FILES = FileList[
  '[A-Z]*',
  'bin/**/*', 
  'lib/**/*', 
]

CLEAN.include('build')

task :default => :package

spec = Gem::Specification.new do |s|
	s.name = PKG_NAME
	s.version = PKG_VERSION
	s.summary = "Remote control interface for MPlayer"
	s.description = <<-EOF
	#{PKG_NAME} implements HTTP protocol used by Vlc to control MPlayer.
	More to the point, I just wanted to use VLC remote android app to control MPlayer.
	EOF

	s.files = PKG_FILES.to_a

	s.bindir = "bin"
	s.executables = ["rmplayer"]
	s.default_executable = "rmplayer"
	
	s.require_path = 'lib'

	s.add_dependency 'builder'

	s.has_rdoc = false

	s.author = "Peter Severin"
	s.email = "peter_p_s@users.sourceforge.net"
end

Rake::GemPackageTask.new(spec) do |p|
	p.need_tar = true
	p.gem_spec = spec
end

desc "Run all the tests"
Rake::TestTask.new do |t|
    t.test_files = FileList['test/test_*.rb', 'test/*_test.rb']
    t.verbose = true
end


desc "Install the gem package"
task :install => :package do |t|
	gem_file = Dir.glob("pkg/#{PKG_NAME}-*.gem").last
	`gem install -l #{gem_file}`
end

desc "Uninstall the gem package"
task :uninstall do |t|
	`echo 'y' | gem uninstall #{PKG_NAME}`
end

