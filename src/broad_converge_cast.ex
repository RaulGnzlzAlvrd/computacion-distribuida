defmodule BroadConvergeCast do
  def inicia id, lider \\ false do
    recibe_mensaje %{
      :id => id,
      :recibidos => 0,
      :lider => lider,
    }
  end

  def recibe_mensaje estado do
    receive do 
      mensaje -> 
        {:ok, nuevo_estado} = procesa_mensaje mensaje, estado
        recibe_mensaje nuevo_estado
    end
  end

  def procesa_mensaje {:vecinos, padre, hijos}, estado do
    nuevo_estado = estado
    |> Map.put(:padre, padre)
    |> Map.put(:hijos, hijos)
    {:ok, nuevo_estado}
  end

  def procesa_mensaje {:inicia}, estado do
    %{ 
      :lider => lider,
      :hijos => hijos,
      :id => id,
      } = estado
    if lider do
      IO.puts "Proceso lider '#{id}' mandó ':start' a hijos."
      Enum.map(hijos, fn hijo -> send hijo, {:start, id} end)
    end
    {:ok, estado}
  end

  def procesa_mensaje {:start, id_padre}, estado do
    %{
      :id => id,
      :hijos => hijos,
      :padre => padre,
      } = estado
    IO.puts "Proceso '#{id}' recibe ':start' de padre '#{id_padre}'."
    if length(hijos) != 0 do
      IO.puts "Proceso '#{id}' mandó ':start' a hijos."
      Enum.map(hijos, fn hijo -> send hijo, {:start, id} end)
    else
      IO.puts "Proceso '#{id}' mandó ':ok' a padre '#{id_padre}'."
      send padre, {:ok, id}
    end
    {:ok, estado}
  end

  def procesa_mensaje {:ok, id_hijo}, estado do
    %{
      :recibidos => recibidos,
      } = estado
    nuevo_estado = Map.put estado, :recibidos, (recibidos + 1)
    %{
      :id => id,
      :recibidos => recibidos,
      :hijos => hijos,
      :lider => lider,
      :padre => padre,
      } = nuevo_estado
    IO.puts "Proceso '#{id}' recibe ':ok' de hijo '#{id_hijo}'."
    if recibidos == length(hijos) do
      if lider do
        IO.puts "Proceso lider '#{id}' termina."
      else
        IO.puts "Proceso '#{id}' mandó ':ok' a padre."
        send padre, {:ok, id}
      end
    end
    {:ok, nuevo_estado}
  end
end

p1 = spawn BroadConvergeCast, :inicia, [1]
p2 = spawn BroadConvergeCast, :inicia, [2]
p3 = spawn BroadConvergeCast, :inicia, [3]
p4 = spawn BroadConvergeCast, :inicia, [4]
p5 = spawn BroadConvergeCast, :inicia, [5]
p6 = spawn BroadConvergeCast, :inicia, [6]
p7 = spawn BroadConvergeCast, :inicia, [7]
p8 = spawn BroadConvergeCast, :inicia, [8]
p9 = spawn BroadConvergeCast, :inicia, [9]
p10 = spawn BroadConvergeCast, :inicia, [10]
p11 = spawn BroadConvergeCast, :inicia, [11, true]
p12 = spawn BroadConvergeCast, :inicia, [12]
p13 = spawn BroadConvergeCast, :inicia, [13]

send p1, {:vecinos, p4, [p12, p13]}
send p2, {:vecinos, p11, []}
send p3, {:vecinos, p9, []}
send p4, {:vecinos, p5, [p1]}
send p5, {:vecinos, p11, [p4, p7]}
send p6, {:vecinos, p8, []}
send p7, {:vecinos, p5, []}
send p8, {:vecinos, p11, [p6, p10]}
send p9, {:vecinos, p10, [p3]}
send p10, {:vecinos, p8, [p9]}
send p11, {:vecinos, nil, [p2, p5, p8]}
send p12, {:vecinos, p1, []}
send p13, {:vecinos, p1, []}

send p1, {:inicia}
send p2, {:inicia}
send p3, {:inicia}
send p4, {:inicia}
send p5, {:inicia}
send p6, {:inicia}
send p7, {:inicia}
send p8, {:inicia}
send p9, {:inicia}
send p10, {:inicia}
send p11, {:inicia}
send p12, {:inicia}
send p13, {:inicia}
