      {:prepared, instance, ballot, a_bal, a_val, sender} ->
        IO.puts("Received 'Prepared' message at Process #{inspect self()} from #{inspect sender}")
        #grab the relavant instance
        #IO.inspect(state)
        instance_state = fetch_instance(state, instance)
        IO.inspect(instance_state)
        #check if instance is aborted for this ballot
        #if the instance is aborted, then we can't accept acks anymore, so return
        
        updated_instance_state = 
          if not instance_state.aborted do 
            #check if we have a quorum
            has_quorum = check_for_quorum?(state.processes, instance_state.prepared + 1)
            updated_instance_state = 
              if has_quorum do
                IO.puts("Found quorum")
                if check_values(instance) do 
                  instance_state = %{instance_state| value: instance_state.proposal }
                  instance_state
                else  
                  #fetch highest ballot value
                  highest_bal = highest_ballot(instance_state.prepared_vals)
                  instance_state = %{instance_state| value: highest_bal }
                  instance_state
                end
                #broadcast the decided 'val' to all processes
                beb_broadcast({:accept, instance, ballot, instance_state.value, self()}, state.processes)
              else
                instance_state
              end
          else
            instance_state
          end
  
        state = %{state | instances: Map.put(state.instances, instance, updated_instance_state )}
        #IO.inspect(state.instances[instance])
        state