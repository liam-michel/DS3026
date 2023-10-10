defmodule Powers do 
  def square(n) do  
    n*n
  end
  def cube(n) do 
    n*square(n)
  end
  def square_or_cube(n,p) when p==2 do 
    square(n)
  end
  def square_or_cube(n,p) when p==3 do 
    cube(n)
  end
  def square_or_cube(_,_) do 
    :error
  end

  def pow(_, 0) do
    1
  end

  def pow(n, p) when p> 0 and is_integer(p) do
    n*pow(n,p-1)
  end

  def pow(n, p) when p<0 and is_integer(p) do
    1 / (n * pow(n, abs(p) - 1))
  end

  def pow(_,_) do
    :error
  end

end