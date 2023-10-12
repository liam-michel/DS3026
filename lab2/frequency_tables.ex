defmodule FrequencyTables do

  def update_freq(key, m) do
    Map.put(m, key, m[key]+1)

  end
end
