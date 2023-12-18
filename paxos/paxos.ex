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
        #add a property to the state map containing the sender process (to send decision to)
        state = %{state | client: sender}
        #check for passed in instance -> create if not there, select if already there
        instance_state = fetch_instance(state.instances, inst)
        #once selected the correct instance -> propose the value
        IO.puts("#{inspect self()} is proposing a value #{inspect value}")
        IO.inspect(state)
        #start prepare -> increment ballot first
        instance_state.current_bal = instance_state.current_bal + 1

        #hit start_propose listener
        send(self(), {:start_propose, instance_state, inst})
        %{state | instances: Map.put(state.instances, inst, instance_state )}


      #called into for sending initial request for preparation to all processes.
      {:start_propose, instance_state, inst} ->
        beb_broadcast({:prepare, self(), inst, instance_state.current_bal}, state.processes)
        state

      #received by processes -> must respond with (prepared) or nack
      {:prepare, sender, inst, ballot} ->
        IO.puts("Received preparation request from process #{inspect sender} on ballot #{inspect ballot}")
        #first fetch given instance
        instance_state = fetch_instance(state, inst)
        #check if new ballot is higher number -> join if so and send ack (:prepared)
        if(ballot > instance_state.current_bal) do  
          instance_state.current_bal = ballot
          #send ack
          send(sender, {:prepared, ballot, instance_state.current_bal, instance_state.current_val})
        else
          #otherwise send nack (i.e. if the proposed ballot is lower than this procs current one)
          send(sender, {:nack, ballot})
        end

        #update local state and return it
        %{state | instances: Map.put(state.instances, inst, instance_state )}

    end


      {:nack, ballot} ->
        IO.puts("Received nack from process, aborting")
        send(state.client, :abort)


      #process the response
      #then check for a quorum
      {:prepared, ballot, a_bal, a_val} ->
      

    run(state)
  end



  #takes in state, and a new instance id. Returns modified state with the new instance
  # defp create_instance(state, instance_id) do
  #   new_instance = default_instance()
  #   IO.puts(new_instance)
  #   modified_state = Map.put_new(state, instance_id, new_instance)
  #   {modified_state, new_instance}
  # end

  defp fetch_instance(state, instance_id) do 
    case Map.get(state, instance_id) do
      nil -> 
        IO.puts("creating new instance")
        %{
        current_bal: -1,
        a_bal: -1,
        a_val: -1,
        value: nil,
        proposal: nil,
        decided: false
        }
      entry -> 
        IO.puts("Found existing instance")
        entry
    end
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
