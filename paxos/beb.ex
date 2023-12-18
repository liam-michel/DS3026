defmodule Beb do
  def start(name, processes) do 
    pid = spawn(Beb, :init, [name, processes])

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
      messages: MapSet.new()
    }
    run(state)
  end

  def run(state) do 
    state = receive do 
      {:broadcast, message} ->
        IO.puts("Broadcasting message from sender #{inspect state.name}")
        # Broadcast a message to all processes
        beb_broadcast(message, state.processes)
        state

      {:deliver, sender, message} ->
        # Deliver a message to the application layer
        IO.puts("Received message from process #{inspect sender}")
        %{state | messages: MapSet.put(state.messages, message)}

      {:ping} -> 
        IO.puts("Pinging process #{inspect self()}")
        #print all delivered messages for this process
        print_delivered_messages(state.messages, self())
        state

    end

    run(state)
  end


  defp unicast(message, process) do
    case :global.whereis_name(process) do 
      pid when is_pid(pid) -> send(pid, {:deliver, self(), message})
      :undefined -> :ok
    end
  end

  defp beb_broadcast(message, processes) do
    for p <- processes, do: unicast(message, p)
  end

  defp print_delivered_messages(messages, process) do
    Enum.map(
      messages,
      fn message -> IO.puts(message) end)
  end
  


end
