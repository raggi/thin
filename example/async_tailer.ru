#!/usr/bin/env rackup -s thin
# 
#  async_tailer.ru
#  raggi/thin
#  
#  Created by James Tucker on 2008-06-18.
#  Copyright 2008 James Tucker <raggi@rubyforge.org>.


class DeferrableBody
  include EventMachine::Deferrable

  def call(body)
    body.each do |chunk|
      @body_callback.call(chunk)
    end
  end

  def each &blk
    @body_callback = blk
  end

end

module TailRenderer
  attr_accessor :callback

  def receive_data(data)
    @callback.call([data])
  end

  def unbind
    @body.succeed
  end
end

class AsyncTailer
  
  AsyncResponse = [100, {}, []].freeze
    
  def call(env)
    
    body = DeferrableBody.new
    
    EventMachine::next_tick do
      
      env['async.callback'].call [200, {'Content-Type' => 'text/html'}, body]
      
      body.call ["<h1>Async Tailer</h1><pre>"]
      
    end
    
    EventMachine::popen('tail -f /var/log/system.log', TailRenderer) do |t|
      
      t.callback = body
      
      # If for some reason we 'complete' body, close the tail.
      body.callback do
        t.close_connection
      end
      
      # If for some reason the client disconnects, close the tail.
      body.errback do
        t.close_connection
      end
      
    end
    
    AsyncResponse
  end
  
end

run AsyncTailer.new