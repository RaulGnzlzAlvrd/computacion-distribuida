defmodule TailRecursion do
  def fact n do _fact n, 1 end
  defp _fact 0, acc do acc end
  defp _fact n, acc do _fact (n - 1), (acc * n) end
end