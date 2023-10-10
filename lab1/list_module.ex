defmodule ListModule do

  def sum_square([]) do
    0
  end
  def sum_square([head | tail]) when is_number(head) do 
    square = head * head 
    square + sum_square(tail)
  end
  def sum_square(_) do 
    "Invalid Input"
  end
  def len([]) do 
    0
  end
  def len([ head | tail]) do 
    1 + len(tail)
  end
  def len(_) do
    "Invalid Input"
  end
  
  def reverse([]), do: []
  
  def reverse([head | tail]) do
    reversed_tail = reverse(tail)
    reversed_tail ++ [head]
  end
end