require 'pp'

class Test
	attr_accessor :qw, :vx
	
	def initialize f, s
		@qw = {'q' => f * 2, 'w' => f - 1}
		@vx = {'v' => s + 10, 'x' => s * -1}
		inc_qw
		inc @vx
	end
	
	def inc_qw
		inc @qw
	end
	
	def tg
		pp @qw
		pp @vx
	end
	
	private
	
	def inc hash
		hash.update(hash){|k, v| v + 1}
	end
end

d = Test.new 4, 17
d.tg