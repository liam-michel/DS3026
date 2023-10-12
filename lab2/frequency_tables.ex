defmodule FrequencyTables do

  def update_freq(key, map) do
    case Map.get(map, key) do
      nil ->
        Map.update(map, key, 1, fn value -> value + 1 end)

      count ->
        Map.update(map, key, count, fn value -> value + 1 end)
    end
  end

  def freq_count_body(list) do
    freq_table = %{}
    Enum.reduce(
      list,
      freq_table,
      fn (x, acc) -> update_freq(x, acc) end
    )
  end

  def word_count(text) do
    split_text = String.split(text, ~r{\W+}, trim: true)
    freq_table = %{}
    Enum.reduce(
      split_text,
      freq_table,
      fn(x, acc) -> update_freq(String.downcase(x), acc) end
    )
  end
  
  def swap_map(input_map) do
    for {k, v} <- input_map, into: [], do: {v, k}
  end

  def ceiling_division(numerator, denominator) when denominator != 0 do
    ceil((numerator / denominator) * 100)
  end

  def to_histogram(map) do
    output_arr = []
    total = Enum.reduce(
      map,
      0,
      fn {_, count}, sum -> sum + count end
    )

    for {k, v} <- map, into: output_arr do
      perc = ceiling_division(v, total)
      {k, perc}
    end
  end


  def sorted_histogram(map) do
    percs = to_histogram(map)
    output = Enum.sort(
      percs,
      fn {_, perc1}, {_, perc2} -> perc1 <= perc2 end
    ) 
    output
  end
end
