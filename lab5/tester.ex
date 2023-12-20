defmodule Tester do
    
    def init(state) do
        Map.put_new(state, :fifo_count, 0)
    end

    def start_test(state, {_, n}) do
        IO.puts("#{inspect state.name}: test started for #{inspect n} iterations")
        send(self(), {:broadcast, {:test, state.fifo_count, n}})
        IO.puts("#{inspect state.name}: CB-broadcast: #{inspect {state.name, state.fifo_count}}")
        %{state | fifo_count: state.fifo_count + 1}
    end

    def proc_test_msg(state, {:deliver, proc, {:test, seqno, n}}) when n > 0 do
        IO.puts("#{inspect state.name}: CB-deliver: #{inspect {proc, seqno}}")
        send(self(), {:broadcast, {:test, state.fifo_count, n-1}})
        IO.puts("#{inspect state.name}: CB-broadcast: #{inspect {proc, state.fifo_count}}")
        %{state | fifo_count: state.fifo_count + 1}
    end

    def proc_test_msg(state, {:deliver, proc, {:test, seqno, n}}) when n == 0 do
        IO.puts("#{inspect state.name}: CB-deliver: #{inspect {proc, seqno}}")
        IO.puts("#{inspect state.name}: test finished")
        state
    end
end