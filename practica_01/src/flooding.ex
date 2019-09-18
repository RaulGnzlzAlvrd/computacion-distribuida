defmodule Flooding do
  
  def inicia id, lider \\ false, mensaje \\ nil do
    estado_inicial = %{
      :id => id, 
      :lider => lider, 
      :flag => false,
      :mensaje => mensaje
    }
    recibe_mensaje estado_inicial
  end

  def recibe_mensaje estado do
    receive do
      mensaje ->
        {:ok, nuevo_estado} = procesa_mensaje mensaje, estado
        recibe_mensaje nuevo_estado
    end
  end

  def procesa_mensaje {:vecinos, vecinos}, estado do
    {:ok, Map.put(estado, :vecinos, vecinos)}
  end

  def procesa_mensaje {:inicia}, estado do
    if estado.lider do
      %{
        :id => id,
        :mensaje => mensaje,
        :vecinos => vecinos,
      } = estado
      IO.puts "Proceso inicial '#{id}', mando mensaje '#{mensaje}' a todos."
      Enum.map vecinos, (fn vecino -> send vecino, {:mensaje, mensaje} end)
      {:ok, Map.put(estado, :flag, true)}
    else
      {:ok, estado}
    end
  end

  def procesa_mensaje {:mensaje, mensaje}, estado do
    {:ok, flooding(estado, mensaje)}
  end

  def flooding estado, mensaje \\ nil do
    %{
      :vecinos => vecinos,
      :flag => flag,
      :id => id,
    } = estado
    if flag do
      estado
    else
      IO.puts "Proceso '#{id}', mando mensaje '#{mensaje}' a todos."
      Enum.map vecinos, (fn vecino -> send vecino, {:mensaje, mensaje} end)
      Map.put(estado, :flag, true)
    end
  end
end

mensaje = "<Message>"

p1 = spawn Flooding, :inicia, [1]
p2 = spawn Flooding, :inicia, [2]
p3 = spawn Flooding, :inicia, [3]
p4 = spawn Flooding, :inicia, [4]
p5 = spawn Flooding, :inicia, [5]
p6 = spawn Flooding, :inicia, [6]
p7 = spawn Flooding, :inicia, [7]
p8 = spawn Flooding, :inicia, [8]
p9 = spawn Flooding, :inicia, [9]
p10 = spawn Flooding, :inicia, [10]
p11 = spawn Flooding, :inicia, [11, true, mensaje]
p12 = spawn Flooding, :inicia, [12]
p13 = spawn Flooding, :inicia, [13]

send p1, {:vecinos, [p4, p12, p13]}
send p2, {:vecinos, [p11]}
send p3, {:vecinos, [p9]}
send p4, {:vecinos, [p1, p5]}
send p5, {:vecinos, [p4, p7, p11]}
send p6, {:vecinos, [p8]}
send p7, {:vecinos, [p5]}
send p8, {:vecinos, [p6, p10, p11]}
send p9, {:vecinos, [p3, p10]}
send p10, {:vecinos, [p8, p9]}
send p11, {:vecinos, [p2, p5, p8]}
send p12, {:vecinos, [p1]}
send p13, {:vecinos, [p1]}

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
