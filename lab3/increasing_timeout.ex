defmodule IncreasingTimeout do
    @delta 1000    
    @delay 5000


    def start(name, processes) do
        pid = spawn(IncreasingTimeout, :init, [name, processes])
        # :global.unregister_name(name)
        case :global.re_register_name(name, pid) do
            :yes -> pid  
            :no  -> :error
        end
        IO.puts "registered #{name}"
        pid
    end

    # Init event must be the first
    # one after the component is created
    def init(name, processes) do 
        state = %{ 
            name: name, 
            processes: List.delete(processes, name),
            delta: @delta, # timeout in millis
            alive: MapSet.new(processes),
            suspected: %MapSet{}
        }
        Process.send_after(self(), {:timeout}, state.delta)
        run(state)
    end

    def run(state) do
        state = receive do 
            {:timeout} ->  
                IO.puts("#{state.name}: #{inspect({:timeout})} #{inspect(state.delta)}ms")
                state = adjust_delta(state)
                state = check_and_probe(state, state.processes)
                state = %{state | alive: %MapSet{}}
                Process.send_after(self(), {:timeout}, state.delta)
                state

            {:heartbeat_request, pid} ->
                IO.puts("#{state.name}: #{inspect({:heartbeat_request, pid})}")
                if state.name == :p1, do: Process.sleep(@delay)

                send(pid, {:heartbeat_reply, state.name})
                state

            {:heartbeat_reply, name} ->
                IO.puts("#{state.name}: #{inspect {:heartbeat_reply, name}}")
                %{state | alive: MapSet.put(state.alive, name)}

            {:suspect, p} -> 
                IO.puts("#{state.name}: started suspecting #{p}")
                state

            {:restore, p} -> 
                IO.puts("#{state.name}: stopped suspecting #{p}")
                state                
        end
        run(state)
    end

    defp adjust_delta(state) do
        %{state | delta: (state.delta + calculate_delta_difference(state))}
    end

    defp calculate_delta_difference(state) do
        if MapSet.disjoint?(state.alive, state.suspected), do: @delta, else: 0
    end

    defp check_and_probe(state, []), do: state
    defp check_and_probe(state, [p | p_tail]) do
        state = if p not in state.alive and p not in state.suspected do 
            state = %{state | suspected: MapSet.put(state.suspected, p)}
            send(self(), {:suspect, p})
            state
        else
            if p in state.alive and p in state.suspected do 
                state = %{state | suspected: MapSet.delete(state.suspected, p)}
                send(self(), {:restore, p})
                state
            else
                state
            end
        end

        case :global.whereis_name(p) do
            pid when is_pid(pid) -> send(pid, {:heartbeat_request, self()})
            :undefined -> :ok
        end

        check_and_probe(state, p_tail)
    end
end