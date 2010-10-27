require 'thread'

module RMPlayer

class MPlayer
	def initialize(args)
		@mutex = Mutex.new

		pstdin, pstdout, pstderr = IO.pipe, IO.pipe, IO.pipe

		command = %w(/usr/bin/mplayer -slave -quiet) + args
		@pid = fork do
			STDIN.reopen pstdin.first
			pstdin.last.close

			STDERR.reopen pstderr.last
			pstderr.first.close

			STDOUT.reopen pstdout.last
			pstdout.first.close

			STDERR.sync = true
			STDOUT.sync = true

			exec(*command)
		end

		pstdin.first.close
		pstderr.last.close
		pstdout.last.close

		@stdin, @stdout, @stderr = pstdin.last, pstdout.first, pstderr.first

		STDERR.sync = true
		STDOUT.sync = true

		sleep 2
	end

	def paused?
		get_property('pause') == 'yes'
	end

	def get_property(property)
		cmd = "pausing_keep_force get_property #{property}"
		match = "ANS_#{property.to_s}"
		rex = /#{match}=(.+)/
		response = send(cmd, rex)
		response[rex, 1]
	end

	def get(property)
		cmd = "pausing_keep_force get_#{property}"
		match = case property
				when "time_pos" then 'ANS_TIME_POSITION'
				when "percent_pos" then 'ANS_PERCENT_POSITION'
				when "time_length" then 'ANS_LENGTH'
				when "file_name" then 'ANS_FILENAME'
				else "ANS_#{property.to_s.upcase}"
				end
		rex = /#{match}=(.+)/
		response = send(cmd, rex)
		response[rex, 1]
	end

	%w(time_pos time_length file_name percent_pos vo_fullscreen).each do |field|
		define_method(field.to_sym) { get(field) }
	end
	
	def pause
		send('pause')
	end

	def quit
		begin
			send('quit')
		ensure
			Process.waitpid(@pid) if @pid
			@pid = nil
		end
	end

	def seek(value)
		send("seek #{value} 2")
	end

	def volume=(value)
		send("volume #{value} 1")
	end

	def volume
		get_property('volume')
	end

	def load_file(file)
		send("loadfile #{file}")
	end

	def toggle_fullscreen
		send('vo_fullscreen')
	end

	def send(cmd, match = nil)
		@mutex.synchronize do
			puts "Sending #{cmd}. Looking for #{match}" if DEBUG
			@stdin.puts(cmd)
			
			return nil if match.nil?

			response = @stdout.gets
			puts "Resp: #{response}. Looking for #{match}" if DEBUG
			until response =~ match
				response = @stdout.gets
				puts "Resp: #{response}. Looking for #{match} in loop" if DEBUG
			end
			puts "Matched response: #{response}" if DEBUG
			response
		end
	end
end

end

