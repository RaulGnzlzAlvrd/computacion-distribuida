defmodule ConvergeCast do
  def inicia id do
    recibe_mensaje %{
      :id => id,
      :recibidos => 0,
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
    if length(estado.hijos) == 0 do
      IO.puts "Iniciando proceso '#{estado.id}'."
      send estado.padre, {:ok}
    end
    {:ok, estado}
  end

  def procesa_mensaje {:ok}, estado do
    %{:recibidos => recibidos} = estado
    nuevo_estado = Map.put estado, :recibidos, (recibidos + 1)
    IO.puts "Proceso '#{nuevo_estado.id}' recibe nuevo mensaje."
    if nuevo_estado.recibidos == length(nuevo_estado.hijos) do
      %{:padre => padre} = estado
      if padre do
        IO.puts "Proceso '#{nuevo_estado.id}' enviando ':#{:ok}' a padre."
        send nuevo_estado.padre, {:ok}
      else 
        IO.puts "Proceso padre '#{nuevo_estado.id}' termina."
      end
    end
    {:ok, nuevo_estado}
  end
end

p1 = spawn ConvergeCast, :inicia, [1]
p2 = spawn ConvergeCast, :inicia, [2]
p3 = spawn ConvergeCast, :inicia, [3]
p4 = spawn ConvergeCast, :inicia, [4]
p5 = spawn ConvergeCast, :inicia, [5]
p6 = spawn ConvergeCast, :inicia, [6]
p7 = spawn ConvergeCast, :inicia, [7]
p8 = spawn ConvergeCast, :inicia, [8]
p9 = spawn ConvergeCast, :inicia, [9]
p10 = spawn ConvergeCast, :inicia, [10]
p11 = spawn ConvergeCast, :inicia, [11]
p12 = spawn ConvergeCast, :inicia, [12]
p13 = spawn ConvergeCast, :inicia, [13]

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
