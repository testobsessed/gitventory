module ViewHelpers
  
  class MyStream
    include EventMachine::Deferrable

    def stream(object)
      @block.call object
    end

    def each(&block)
      @block = block
    end
  end
  
  
  def asset(location)
    "/#{location}"
  end
  
  def get_foo_records
    out = MyStream.new
    body out
    
    EM.next_tick do
      c = 0
      out.stream("<table>")
      timer = EM.add_periodic_timer(0.3) do
        c += 1
        @message = "this is part #{c}"
        @thing = "THING #{c}"
        puts partial(:foo_partial)
        out.stream(partial(:foo_partial))
        if (c == 15)
          timer.cancel
          out.stream("</table>")
          out.succeed
        end
      end
    end
  end
end
