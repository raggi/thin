require 'thread'

class HijackChat
  def initialize
    @chatters = []
    @buffers = Hash.new { |h, io| h[io] = "" }
    @mutex = Mutex.new
  end

  def call(env)
    headers = {}
    headers['rack.hijack'] = proc do |io|
      io.write "Welcome to HijackChat!\n"
      io.flush
      puts "Hijacked: #{io.inspect}"
      chatters { |c| c << io }
    end
    [200, headers, []]
  end

  def start
    @thread = Thread.new do
      Thread.current.abort_on_exception = true

      active = false
      while true
        each do |c|
          if line = buffer(c)
            puts "Got line: #{line.inspect}"
            active = true
            distribute line, c
          end
        end
        # Very poor mans CPU backoff...
        sleep 0.2 unless active
      end
    end
  end

  def buffer c
    buf = @buffers[c]
    buf << c.read_nonblock(65536)
    buf.slice!(/.+(?:\r\n|[\r\n])/)
  rescue IO::WaitReadable
    # do nothing
  rescue IOError
    # whatever...
    kill c
    nil
  end

  def distribute line, source
    each do |c|
      next if c == source
      safe_write line, c
    end
  end

  def safe_write line, c
    # Sync write, because it's a demo right??
    c.write line
    c.flush
  rescue IOError
    # whatever...
    kill c
    nil
  end

  def kill c
    c.close
    @buffers.delete c
    @chatters.delete c
  end

  def each &block
    chatters { |cs| cs.dup }.each &block
  end

  def chatters
    @mutex.synchronize do
      yield @chatters
    end
  end
end

app = HijackChat.new
app.start

run app
