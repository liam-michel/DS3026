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



  
  
end
