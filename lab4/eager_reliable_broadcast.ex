defmodule EagerReliableBroadcast do
    def start(name, processes) do
        pid = spawn(EagerReliableBroadcast, :init, [name, processes])
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
            processes: processes,
            delivered: %MapSet{},  # Use this data structure to remember IDs of the delivered messages
            seq_no: 0 # Use this variable to remember the last sequence number used to identify a message
        }
        run(state)
    end

    def run(state) do
        state = receive do 
            # Handle the broadcast request event
            {:broadcast, m} -> 
                IO.puts("#{inspect state.name}: RB-broadcast: #{inspect m}")
                # Create a unique message identifier from state.name and state.seqno.
                # Create a new data message data_msg from the given payload m
                # the message identifier.
                # Update the state as necessary
                
                # Use the provided beb_broadcast function to propagate data_msg to 
                # all process
                beb_broadcast(data_msg, state.processes)
                state    # return the updated state

            {:data, proc, seq_no, m} ->
               # If <proc, seqno> was already delivered, do nothing.
               # Otherwise, update delivered, generate a deliver event for the
               # upper layer, and re-broadcast (echo) the received message.
               # In both cases, do not forget to return the state.
               state

            {:deliver, proc, m} ->
                # Simulate the deliver indication event
                IO.puts("#{inspect state.name}: RB-deliver: #{inspect m} from #{inspect proc}")
                state
        end
        run(state)
    end


    defp unicast(m, p) do
        case :global.whereis_name(p) do
                pid when is_pid(pid) -> send(pid, m)
                :undefined -> :ok
        end
    end

    defp beb_broadcast(m, dest), do: for p <- dest, do: unicast(m, p)

    # You can use this function to simulate a process failure.
    # name: the name of this process
    # proc_to_fail: the name of the failed process
    # fail_send_to: list of processes proc_to_fail will not be broadcasting messages to
    # Note that this list must include proc_to_fail.
    # m and dest are the same as the respective arguments of the normal
    # beb_broadcast.
    defp beb_broadcast_with_failures(name, proc_to_fail, fail_send_to, m, dest) do
        if name == proc_to_fail do
            for p <- dest, p not in fail_send_to, do: unicast(m, p)
        else
            for p <- dest, p != proc_to_fail, do: unicast(m, p)
        end
    end

end