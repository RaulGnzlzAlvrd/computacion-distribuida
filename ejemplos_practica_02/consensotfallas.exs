defmodule ConsensoTFallas do
  def inicio do
    estado_inicial = %{:prop => 0, :vista => %{}, :envio_mensaje => false,
                       :fallido => false, :ronda => 0, :continua => false,
                       :inicio_ronda => nil, :prob_fallo => 0, :cambio_ronda => false}
    recibe_mensaje(estado_inicial)
  end

  def recibe_mensaje(estado) do
    receive do
      mensaje ->
        {:ok, nuevo_estado} = procesa_mensaje(mensaje, estado)
        recibe_mensaje(nuevo_estado)
    end
  end

  def procesa_mensaje({:id, id}, estado) do
    estado = Map.put(estado, :id, id)
    {:ok, estado}
  end

  def procesa_mensaje({:vecinos, vecinos}, estado) do
    estado = Map.put(estado, :vecinos, vecinos)
    {:ok, estado}
  end

  def procesa_mensaje({:prop, prop}, estado) do
    estado = Map.put(estado, :prop, prop)
    {:ok, estado}
  end

  def procesa_mensaje({:inicia}, estado) do
    estado = consenso(estado)
    {:ok, estado}
  end

  def procesa_mensaje({:continua}, estado) do
    estado = consenso(estado)
    {:ok, estado}
  end

  def procesa_mensaje({:t, t}, estado) do
    estado = Map.put(estado, :t, t)
    {:ok, estado}
  end

  def procesa_mensaje({:timeout_prop, ronda}, estado) do
    # Liberamos el buffer si ya pasaron 100ms y aún no hemos hecho la
    # decisión de la ronda
    %{:inicio_ronda => inicio, :continua => continua?, :ronda => r, :cambio_ronda => cambio} = estado
    t = :os.system_time(:millisecond)
    estado = if (t - inicio) > 100 and ronda == r and not continua? and not cambio do
      estado = consenso(%{estado | :cambio_ronda => true, :continua => true})
      send self(), {:continua}
      estado
    else
      send self(), {:timeout_prop, ronda}
      estado
    end
    {:ok, estado}
  end

  def procesa_mensaje({:id, id, :prop, prop, :ronda, r}, estado) do
    # Agregamos los mensajes si son de la ronda en la que estamos
    %{:vista => vista, :ronda => ronda} = estado
    estado = if r == ronda do
      vista = Map.put(vista, id, prop)
      %{estado | :vista => vista}
    else
      estado
    end
    send self(), {:timeout_prop, r}
    {:ok, estado}
  end

  def procesa_mensaje({:fallido, fallido, :prob_fallo, prob}, estado) do
    estado = %{estado | :fallido => fallido, :prob_fallo => prob}
    {:ok, estado}
  end

  defp envio_al_menos_un_mensaje do
    (:rand.uniform(16) > 8)
  end

  defp fallos(estado) do
    %{:vecinos => vecinos, :id => id, :prop => prop, :prob_fallo => prob,
      :ronda => ronda} = estado
    if :rand.uniform() <= prob do
      if envio_al_menos_un_mensaje() do
        IO.puts "ID (#{id}): Voy a morir en la ronda #{ronda}, pero al menos enviaré algún mensaje"
        n = Enum.count(vecinos)
        random = :rand.uniform(n)
        new_vecs = vecinos |> Enum.shuffle |> Enum.take(random)
        Enum.map(new_vecs, fn v -> send v, {:id, id, :prop, prop, :ronda, ronda} end)
      else
        IO.puts "ID (#{id}): Muriendo sin haber amado en la ronda #{ronda}"
      end
      Process.exit(self(), :kill)
    end

  end

  def consenso(estado) do
    %{:vista => vista, :vecinos => vecinos,
      :continua => continua?, :id => id, :prop => prop,
      :envio_mensaje => envio?, :fallido => fallido?,
      :ronda => ronda, :t => t} = estado
    inicio = :os.system_time(:millisecond)
    if ronda < (t + 1) do
      estado = if not envio? do
        if fallido? do
          fallos(estado)# Simulamos fallos aleatorios
        else # Envíamos nuestros mensajes normalmente
          Enum.map(vecinos, fn v -> send v, {:id, id, :prop, prop, :ronda, ronda} end)
        end
        %{estado | :envio_mensaje => true, :inicio_ronda => inicio}
      else
        estado
      end
      # Esperamos a recuperar los mensajes
      if continua? do
        vista = Map.put(vista, id, prop)
        min   = Enum.min(Map.values(vista))
        %{estado | :envio_mensaje => false, :continua => false,
                   :prop => min, :ronda => (ronda + 1), :cambio_ronda => false}
      else
        estado
      end
    else
      # Mostramos la decisión
      IO.puts "Soy el proceso #{id} y la decisión es #{prop} en la ronda #{ronda}"
      Process.exit(self(), :kill)
    end
  end

end

a = spawn(ConsensoTFallas, :inicio, [])
b = spawn(ConsensoTFallas, :inicio, [])
c = spawn(ConsensoTFallas, :inicio, [])
d = spawn(ConsensoTFallas, :inicio, [])
e = spawn(ConsensoTFallas, :inicio, [])
f = spawn(ConsensoTFallas, :inicio, [])
g = spawn(ConsensoTFallas, :inicio, [])
h = spawn(ConsensoTFallas, :inicio, [])
i = spawn(ConsensoTFallas, :inicio, [])
j = spawn(ConsensoTFallas, :inicio, [])
k = spawn(ConsensoTFallas, :inicio, [])
l = spawn(ConsensoTFallas, :inicio, [])
m = spawn(ConsensoTFallas, :inicio, [])
n = spawn(ConsensoTFallas, :inicio, [])


send a, {:id, "a"}
send a, {:prop, 1}
send a, {:vecinos, [b, c, d, e, f, g, h, i, j, k, l, m, n]}
send a, {:fallido, true, :prob_fallo, 0.1} # Este proceso falla desde el inicio
send a, {:t, 6}
send b, {:id, "b"}
send b, {:vecinos, [a, c, d, e, f, g, h, i, j, k, l, m, n]}
send b, {:prop, 2}
send b, {:t, 6}
send c, {:id, "c"}
send c, {:vecinos, [a, b, d, e, f, g, h, i, j, k, l, m, n]}
send c, {:prop, 2}
send c, {:t, 6}
send d, {:id, "d"}
send d, {:vecinos, [a, b, c, e, f, g, h, i, j, k, l, m, n]}
send d, {:prop, 2}
send d, {:fallido, true, :prob_fallo, 0.2}
send d, {:t, 6}
send e, {:id, "e"}
send e, {:vecinos, [a, b, c, d, f, g, h, i, j, k, l, m, n]}
send e, {:prop, 3}
send e, {:fallido, true, :prob_fallo, 0.4}
send e, {:t, 6}
send f, {:id, "f"}
send f, {:vecinos, [a, b, c, d, e, g, h, i, j, k, l, m, n]}
send f, {:prop, 3}
send f, {:t, 6}
send g, {:id, "g"}
send g, {:vecinos, [a, b, c, d, e, f, h, i, j, k, l, m, n]}
send g, {:prop, 3}
send g, {:t, 6}
send h, {:id, "h"}
send h, {:vecinos, [a, b, c, d, e, f, g, i, j, k, l, m, n]}
send h, {:prop, 4}
send h, {:fallido, true, :prob_fallo, 0.8}
send h, {:t, 6}
send i, {:id, "i"}
send i, {:vecinos, [a, b, c, d, e, f, g, h, j, k, l, m, n]}
send i, {:prop, 4}
send i, {:fallido, true, :prob_fallo, 0.1}
send i, {:t, 6}
send j, {:id, "j"}
send j, {:vecinos, [a, b, c, d, e, f, g, h, i, k, l, m, n]}
send j, {:prop, 4}
send j, {:t, 6}
send k, {:id, "k"}
send k, {:vecinos, [a, b, c, d, e, f, g, h, i, j, l, m, n]}
send k, {:prop, 4}
send k, {:t, 6}
send l, {:id, "l"}
send l, {:vecinos, [a, b, c, d, e, f, g, h, i, j, k, m, n]}
send l, {:prop, 4}
send l, {:fallido, true, :prob_fallo, 0.5}
send l, {:t, 6}
send m, {:id, "m"}
send m, {:vecinos, [a, b, c, d, e, f, g, h, i, j, k, l, n]}
send m, {:prop, 2}
send m, {:t, 6}
send n, {:id, "n"}
send n, {:vecinos, [a, b, c, d, e, f, g, h, i, j, k, l, m]}
send n, {:prop, 3}
send n, {:t, 6}

send a, {:inicia}
send b, {:inicia}
send c, {:inicia}
send d, {:inicia}
send e, {:inicia}
send f, {:inicia}
send g, {:inicia}
send h, {:inicia}
send i, {:inicia}
send j, {:inicia}
send k, {:inicia}
send l, {:inicia}
send m, {:inicia}
send n, {:inicia}
