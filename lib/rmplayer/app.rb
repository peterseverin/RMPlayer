require 'webrick'
require 'builder'
require 'rmplayer/mplayer'

module RMPlayer
	DEBUG = false

class NullLogger
	def method_missing(*args)
	end
end

class App
	def run(args)
		@mplayer = MPlayer.new(args)

		s = ::WEBrick::HTTPServer.new(:Port => 8080,
					      :MaxClients => 5,
					      :DoNotReverseLookup => true,
					      :ShutdownSocketWithoutClose => true,
					      :Logger => DEBUG ? nil : NullLogger.new)

		s.mount_proc('/requests/status.xml') do |req, resp|
			begin
				command = req.query['command'] || 'status'

				puts "Executing #{command}" if DEBUG

				case command
				when 'in_play'
					file = req.query['input']
					if @mplayer
						@mplayer.load_file file
					else
						@mplayer = MPlayer.new file
					end
				when 'fullscreen'
					@mplayer.toggle_fullscreen
				when 'seek'
					val = req.query['val'].to_i
					@mplayer.seek(val)
				when 'volume'
					val = req.query['val'].to_i
					@mplayer.volume = ((val * 100.0) / 1024).to_i
				when 'pl_next'
				when 'pl_previous'
				when 'pl_pause', 'pl_play'
					@mplayer.pause
				when 'pl_stop'
					quit_mplayer
				end

				resp.status = 200
				resp['Content-Type'] = 'text/xml'
				resp.body = status
			rescue Errno::EPIPE => ex
				quit_mplayer
				resp.status = 500
			end
		end

		s.mount_proc('/requests/browse.xml') do |req, resp|
			dir = req.query['dir']

			resp.status = 200
			resp['Content-Type'] = 'text/xml'
			resp.body = browse(dir)
		end

		trap("INT") do
			quit_mplayer
			s.shutdown
		end

		Socket.do_not_reverse_lookup = true

		s.start
	end

	def quit_mplayer
		if @mplayer
			begin
				@mplayer.quit
				@mplayer = nil
			rescue Exception => ignore
			ensure
				@mplayer = nil
			end
		end
	end

	def status
		xml = Builder::XmlMarkup.new
		xml.root do
			xml.volume @mplayer ? ((@mplayer.volume.to_i * 1024.0) / 100).to_i : 256
			xml.length @mplayer ? @mplayer.time_length.to_i : 0
			xml.time @mplayer ? @mplayer.time_pos.to_i : 0
			xml.state @mplayer ? (@mplayer.paused? ? 'paused' : 'playing') : 'stop'
			xml.position @mplayer ? @mplayer.percent_pos.to_i : 0
			xml.fullscreen
			xml.loop 0
			xml.repeat 0
			xml.information do
				xml.tag! :'meta-information' do
					xml.title @mplayer ? @mplayer.file_name : ''
				end
			end
		end

		puts xml.target! if DEBUG
		xml.target!
	end

	def browse(dir)
		base = File.expand_path(dir)
		files = Dir.new(base).entries.sort

		xml = Builder::XmlMarkup.new
		xml.root do
			files.each do |name|
				f = "#{base}/#{name}"

				next unless show_file?(f, name)

				xml.element :type => (File.directory?(f) ? 'directory' : 'file'),
					:size => File.size(f),
					:date => File.mtime(f),
					:path => f,
					:name => File.basename(f),
					:extension => File.extname(f)
			end
		end

		puts xml.target! if DEBUG
		xml.target!
	end

	def show_file?(file, name)
		return true if name == '..'
		return false if name[0, 1] == '.'
		return true if File.directory?(file)
		return %w(.avi .mpg .mpeg .mk4 .mov .ogg .mp3).include?(File.extname(name))
	end
end
end
