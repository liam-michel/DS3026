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

  #initialise state with name (the given process), list of processes, map for the different instances,
  #ballot_constant and rank used for generating unique ballot ids for all proposing processes
  def init(name, processes) do
    state = %{
      name: name,
      processes: processes,
      instances: %{},
      ballot_constant: length(processes),
      rank: calculate_rank(name, processes)
    }
    run(state)
  end

  #function that takes a target and a list of processes, returns the index of the target element in the list
  def calculate_rank(target, processes) do
    Enum.find_index(processes, fn process -> process == target end)
  end

  #used to fetch a decision of a given instance from a given process (pid)
  def get_decision(pid, inst, t) do
    send(pid, {:fetch_decision, inst, self()})
    receive do
      {:decided_value, ^inst, v} ->
        v
    after
      t ->
        nil
    end
  end

  #called by external user (higher level layer) to propose a value at a given process and instance with a timeout
  def propose(pid, inst, value, t) do
    send(pid, {:client_propose, inst, value, self()})

    receive do
      #indicates that a given instance has decided a value
      {:decided , ^inst, v} ->
        IO.puts("Processes have decided on value #{inspect v}")
        {:decision, v}

      {:abort, ^inst, ballot} ->
        IO.puts("Aborted instance ID #{inspect inst} on ballot #{inspect ballot}")
        {:abort}

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
        #add a property to the state map containing the sender process (to send decision to)
        state = Map.put(state, :client, sender)
        #check for passed in instance -> create if not there, select if already there
        instance_state = fetch_instance(state.instances, inst)
        #once selected the correct instance -> propose the value
        #start prepare -> increment ballot first and reset abort to false
        if not instance_state.decided and not instance_state.proposed do
          new_ballot_id = state.rank
          instance_state = %{instance_state| myballot: new_ballot_id, aborted: false, accepted: false, proposal: value, decided: false, client: sender}
          IO.puts("Process #{inspect self()} proposing value #{inspect value} on instance #{inspect inst} with ballot #{inspect new_ballot_id}" )
          #broadcast the new ballot with the given ballot id
          beb_broadcast({:prepare, self(), inst, new_ballot_id}, state.processes)
          #return updated state
          state = %{state | instances: Map.put(state.instances, inst, instance_state), rank: new_ballot_id + state.ballot_constant}
          #IO.inspect(state)
          #IO.inspect(state)
          state
        else
          send(sender, {:decided, inst, instance_state.decided_val})
          state
        end


      {:fetch_decision, instance, sender } ->
        instance_state = fetch_instance(state.instances, instance)
        send(sender, {:decided_value, instance, instance_state.decided_val})
        state


      {:receive_decision, inst, decision} ->
        IO.puts("Process #{inspect self()} deciding value: #{inspect decision}")
        instance_state = fetch_instance(state.instances, inst)
        updated_instance_state = %{instance_state| decided_val: decision, decided: true}
        state = %{state | instances: Map.put(state.instances, inst, updated_instance_state )}
        if updated_instance_state.client do
          send(updated_instance_state.client, {:decided, inst, updated_instance_state.value})
        end
        state

      #upon receiving a nack, abort the given instance -> update the instance state and send :abort to client
      {:nack, instance, ballot} ->
        IO.puts("Received nack from instance #{inspect instance}, aborting ballot #{inspect ballot}")
        instance_state = fetch_instance(state.instances, instance)
        instance_state = %{instance_state| aborted: true, accepted: false, prepared: false, prepared_count: 0, accepted_count: 0}
        send(instance_state.client, {:abort, instance, ballot})
        state = %{state | instances: Map.put(state.instances, instance, instance_state )}
        state


      #received by processes -> must respond with (prepared) or nack
      {:prepare, sender, inst, ballot} ->
        instance_state = fetch_instance(state.instances, inst)
        updated_instance_state =
          #if proposing a higher ballot, have this process join the new ballot (set its current_bal to incoming ballot)
          if ballot > instance_state.current_bal do
            new_instance_state = %{instance_state | current_bal: ballot}
            IO.puts("sending prepare ACK for ballot #{inspect ballot}")
            #send ack
            send(sender, {:prepared, inst, ballot, instance_state.a_bal, instance_state.a_val, self()})
            new_instance_state
          else
            #otherwise send nack (i.e. if the proposed ballot is lower than this procs current one)
            IO.puts("#{inspect self()} sending NACK in prepare phase, ballot = #{inspect ballot}, current ballot = #{inspect instance_state.current_bal}")
            send(sender, {:nack, inst, ballot})
            instance_state
          end
                #update local state and return it
        state = %{state | instances: Map.put(state.instances, inst, updated_instance_state )}
        state


      #process the response
      #then check for a quorum
      {:prepared, instance, ballot, a_bal, a_val, sender} ->
        #grab the relavant instance
        instance_state = fetch_instance(state.instances, instance)

        instance_state =
          if not instance_state.aborted and not instance_state.prepared and ballot==instance_state.myballot do
            IO.puts("Delivered 'Prepared' message at Process #{inspect self()} for ballot #{inspect ballot}")

            instance_state = %{instance_state| prepared_count: instance_state.prepared_count + 1,  prepared_vals: Map.put(instance_state.prepared_vals, a_bal, a_val) }
            IO.puts("Ballot #{inspect ballot} Prepared count: #{instance_state.prepared_count}")
            IO.puts("printing prepared_vals")
            IO.inspect(instance_state.prepared_vals)
            instance_state
          else
            instance_state
          end
        #check if instance is aborted for this ballot
        #if the instance is aborted, then we can't accept acks anymore, so return
        has_quorum = check_for_quorum?(state.processes, instance_state.prepared_count)

        updated_instance_state =
          #check if we have a quorum
          if has_quorum and not instance_state.aborted and not (instance_state.prepared) and ballot == instance_state.myballot do
            IO.puts("Found quorum in preparation phase for ballot #{inspect ballot} ")
            instance_state =
              if check_values?(instance_state.prepared_vals) do
                IO.puts("all gathered values are nil")
                %{instance_state| value: instance_state.proposal }
              else
                IO.puts("Non nil value detected")
                IO.inspect(instance_state.prepared_vals)
                #fetch highest ballot value
                val = highest_ballot(instance_state.prepared_vals)
                IO.puts("Picked out #{inspect val} from previous ballot values")
                %{instance_state| value: val }

              end
            #broadcast the decided 'val' to all processes
            IO.puts("Broadcasting value #{inspect instance_state.value}")
            beb_broadcast({:accept, instance, ballot, instance_state.value, self()}, state.processes)
            #update instance state to show that this instance has already broadcastes its proposal
            instance_state = %{instance_state| prepared: true, prepared_count: 0 }
            instance_state
          else
            instance_state
          end

        state = %{state | instances: Map.put(state.instances, instance, updated_instance_state )}
        state

      {:accept, instance, ballot, value, sender} ->
        IO.puts("Received accept request from process #{inspect sender} on ballot #{inspect ballot} at #{inspect self()} ")
        instance_state = fetch_instance(state.instances, instance)
        updated_instance_state =
          if ballot >= instance_state.current_bal and not instance_state.decided do
            IO.puts("accepting value #{inspect value} at processs #{inspect self()} for ballot #{inspect ballot}")
            new_instance_state = %{instance_state| current_bal: ballot, a_bal: ballot, a_val: value}
            send(sender, {:accepted, instance, ballot})
            new_instance_state
          else
            IO.puts("Interrupting ballot #{inspect ballot}, higher ballot has prepared before this can accept")
            send(sender, {:nack, instance, ballot})
            instance_state
          end
        #return updated state
        state = %{state | instances: Map.put(state.instances, instance, updated_instance_state )}
        state



      {:accepted, instance, ballot} ->
        instance_state = fetch_instance(state.instances, instance)
        instance_state =
          if not instance_state.decided and not instance_state.aborted and not instance_state.accepted and instance_state.current_bal == ballot do
            instance_state = %{instance_state| accepted_count: instance_state.accepted_count + 1}
            instance_state
          else
            instance_state
          end
        has_quorum = check_for_quorum?(state.processes, instance_state.accepted_count)
        updated_instance_state =
          if has_quorum and not instance_state.aborted and not instance_state.decided and instance_state.current_bal == ballot and not instance_state.accepted do
            IO.puts("found quorum in acceptance, accepting value #{inspect instance_state.value}")
            IO.puts("sending response to upper layer")
            #broadcast the decision to all processes
            IO.inspect(instance_state.value)
            beb_broadcast({:receive_decision, instance, instance_state.value}, state.processes)
            instance_state = %{instance_state| accepted: true, accepted_count: 0}
            instance_state
          else
            instance_state
          end

        state = %{state | instances: Map.put(state.instances, instance, updated_instance_state )}
        state


    end

    run(state)
  end

  defp fetch_instance(state, instance_id) do
    case Map.get(state, instance_id) do
      nil ->
        %{
        myballot: nil,
        current_bal: -1,
        a_bal: -1,
        a_val: nil,
        value: nil,
        prepared_vals: %{},
        prepared: false,
        proposed: false,
        accepted: false,
        proposal: nil,
        decided: false,
        aborted: true,
        decided_val: nil,
        prepared_count: 0,
        accepted_count: 0,
        client: nil
        }
      entry ->
        entry
    end
  end

  defp check_for_quorum?(list, count) do
    count >= length(list) /2
  end

  defp check_values?(list) do
    Enum.all?(list, fn {_, value} -> is_nil(value) end)
  end

  def highest_ballot(map) do
    Enum.reduce(map, nil, fn {key, value}, acc ->
      if acc === nil || key > elem(acc, 0) do
        IO.puts("Picked out value #{inspect value} from previous accepted values")
        value
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
