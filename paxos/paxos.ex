defmodule Paxos do
  #start function to initialise paxos process(es)
  def start(name, participants) do 
    pid = spawn(Paxos, :init, [name, participants])

    case :global.re_register_name(name, pid) do
      :yes -> pid  
      :no  -> :error
    end

    IO.puts "registered #{name}"
    pid
  end


  def init(name, processes) do
    state = %{
      name: name,
      processes: processes,
      instances: %{}
    }
    run(state)
  end


  #called by external user (higher level layer) to propose a value at a given process and instance with a timeout
  def propose(pid, inst, value, t) do
    send(pid, {:client_propose, inst, value, self()})

    receive do
      m -> m
    after 
      t ->
        {:timeout}
    end
  end


  #actual consensus
  def run(state) do 
    state = receive do 

      #listener for initial propose call
      {:client_propose, inst, value, sender} ->
        IO.puts("Process #{inspect self()} is proposing a value" )
        #add a property to the state map containing the sender process (to send decision to)
        state = Map.put(state, :client, sender)
        #check for passed in instance -> create if not there, select if already there
        instance_state = fetch_instance(state.instances, inst)
        #once selected the correct instance -> propose the value
        #start prepare -> increment ballot first
        instance_state = %{instance_state| current_bal: instance_state.current_bal + 1}
        instance_state = %{instance_state| proposal: value}

        IO.puts("printing state for proposer")
        beb_broadcast({:prepare, self(), inst, instance_state.current_bal}, state.processes)
        #return updated state
        state = %{state | instances: Map.put(state.instances, inst, instance_state )}
        state


      {:check_state} ->
        IO.inspect(state)


      #received by processes -> must respond with (prepared) or nack
      {:prepare, sender, inst, ballot} -> 
        IO.puts("Received preparation request from process #{inspect sender} on ballot #{inspect ballot} at #{inspect self()}")
        instance_state = fetch_instance(state, inst)
        updated_instance_state = 
          if ballot > instance_state.current_bal do 
            IO.puts(instance_state.current_bal)
            IO.puts(ballot)
            new_instance_state = %{instance_state | current_bal: ballot} 
            IO.puts("sending ACK")
            #send ack
            send(sender, {:prepared, inst, ballot, instance_state.a_bal, instance_state.a_val, self()})
            new_instance_state
          else
            #otherwise send nack (i.e. if the proposed ballot is lower than this procs current one)
            send(sender, {:nack, inst, ballot})
            instance_state
          end
                #update local state and return it
        IO.puts("returning state for Process #{inspect self()}")
        state = %{state | instances: Map.put(state.instances, inst, updated_instance_state )}
        state


      {:nack, instance, ballot} ->
        IO.puts("Received nack from process in Paxos instance #{inspect instance}, aborting")
        send(state.client, :abort)


      {:accept, instance, ballot, value, sender} ->

    
      #process the response
      #then check for a quorum
      {:prepared, instance, ballot, a_bal, a_val, sender} ->
        IO.puts("Received 'Prepared' message at Process #{inspect self()} from #{inspect sender}")
        #grab the relavant instance
        #IO.inspect(state)
        instance_state = fetch_instance(state, instance)
        instance_state = %{instance_state| accepted: instance_state.accepted + 1 }
        instace_state = %{instance_state| prepared_val: Map.put(instace_state.prepared_vals, a_bal, a_val)}

        #check if we have a quorum
        has_quorum = check_for_quorum(state.processes, instance_state.accepted)
        updated_instance_state = 
          if has_quorum do
            if check_values(instance) do 
              %{instance_state| value: instance_state.proposal }
              instance_state
            else  
              #fetch highest ballot value
              highest_bal = highest_ballot(instance_state.prepared_vals)
              %{instance_state| value: highest_bal }
              instance_state
            end
            #broadcast the decided 'val' to all processes
            beb_broadcast({:accept, inst, ballot, updated_instance_state.value, self() })
          end

            
          state = %{state | instances: Map.put(state.instances, inst, updated_instance_state), state.processes}
          state

    end


    run(state)
  end

  defp fetch_instance(state, instance_id) do 
    case Map.get(state, instance_id) do
      nil -> 
        %{
        current_bal: -1,
        a_bal: -1,
        a_val: -1,
        value: nil,
        prepared_vals: %{}
        proposal: nil,
        decided: false,
        aborted: false,
        prepared: 0,
        accepted: 0
        }
      entry -> 
        entry
    end
  end

  defp check_for_quorum?(list, count) do 
    requirement = div(length(list), 2) + rem(length(list), 2)
    count >= requirement
  end

  defp check_values(list) do 
    Enum.all?(list, fn {_, value} -> is_nil(value) end)
  end

  def highest_ballot(map) do
    Enum.reduce(map, nil, fn {key, value}, acc ->
      if acc === nil || key > elem(acc, 0) do
        {key, value}
      else
        acc
      end
    end)
  end

  defp unicast(message, process) do
    case :global.whereis_name(process) do 
      pid when is_pid(pid) -> send(pid, message)
      :undefined -> :ok
    end
  end

  defp beb_broadcast(message, processes) do
    for p <- processes, do: unicast(message, p)
  end

  


end
