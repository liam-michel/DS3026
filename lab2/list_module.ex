defmodule ListModule do
  def sum(lst) do
    do_sum(lst, 0)
  end

  defp do_sum([], acc) do
    acc
  end

  defp do_sum([head | tail], acc) do
    do_sum(tail, acc + head)
  end

  def len(lst) do
    do_len(lst, 0)
  end

  defp do_len([], acc) do
    acc
  end

  defp do_len([head | tail ], acc) do
    do_len(tail, acc + 1 )

  end

  def reverse(lst) do
    do_reverse(lst, [])

  end

  defp do_reverse([], acc) do
    acc
  end

  defp do_reverse([head | tail], acc) do
    do_reverse(tail , [head] ++ acc)
  end

  def span(from , to) when from > to  do
    []
  end

  def span(from, to) when from <= to  do
    [from] ++ span(from+1, to)
  end

  def span_tail(from, to) do
    do_span_tail(from, to, [])
  end

  defp do_span_tail(from, to , acc) when from > to do
    acc
  end

  defp do_span_tail(from, to, acc) do
    do_span_tail(from+1, to, acc++[from])
  end

  def square_list(lst) do
    Enum.map(lst, &(&1 * &1))
  end

  def filter3(lst) do
    Enum.filter(lst, fn x -> rem(x, 3) == 0 end)
  end

  def square_and_filter3(lst) do
    lst |>
    square_list() |>
    filter3()
  end

  def square_comprehension(lst) do
    for x <- lst do
      x*x
    end
  end

  def filter3_comp_if(lst) do
    result = for x <- lst do
      if rem(x,3) ==0 do
        x
      end
    end
  Enum.reject(result, fn x -> x == nil end )
  end

  def filter3_comp(lst) do
    for x <- lst, rem(x,3)==0, do: x
  end

  def square_filter3_comp(lst) do
    for x <- lst, rem(x,3) ==0, do: x * x
  end

  def sum_reduce(lst) do
    Enum.reduce(
      lst,
      0,
      fn(element, sum) -> sum + element end
    )
  end

  def len_reduce(lst) do
    Enum.reduce(
      lst,
      0,
      fn(_, sum) -> sum + 1 end
    )
  end

  def reverse_reduce(lst) do
    Enum.reduce(
      lst,
      [],
      fn(element, sum) -> [element] ++ sum end
    )
  end

  def flatten([]), do: []

  def flatten([head | tail]) do
    flatten(head) ++ flatten(tail)
  end

  def flatten(head), do: [ head ]

end
