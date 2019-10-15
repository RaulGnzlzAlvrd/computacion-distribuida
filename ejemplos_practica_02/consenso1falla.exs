defmodule Consenso1Falla do

  def inicio do
    estado_inicial = %{:prop => 0, :propuestas => %{}, :decide => false,
                       :envio_mensaje => false, :fallido => false,
                       :prob_fallo => 0, :ronda => 0, :min => nil,
                       :minimos => %{}, :continua => false,
                       :inicio_ronda => nil, :prop_recibidas => false}
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
    estado = %{estado | :prop => prop}
    {:ok, estado}
  end

  def procesa_mensaje({:inicia}, estado) do
    estado = consenso(estado)
    {:ok, estado}
  end

  def procesa_mensaje(:timeout_prop, estado) do
    %{:inicio_ronda => inicio, :continua => continua?} = estado
    t = :os.system_time(:millisecond)
    # Esperamos un segundo para enviar todos los mensajes que
    # recibimos. Y además verificamos que aún no se activa la bandera
    # de continuar con el envío de los mínimos. En otro caso seguimos
    # checando el tiempo transcurrido.
    estado = if (t - inicio) > 1000 and not continua? do
      consenso(%{estado | :continua => true})
    else
      send self(), :timeout_prop
      estado
    end
    {:ok, estado}
  end

  def procesa_mensaje({:id, id, :propuesta, prop, :ronda, r}, estado) do
    %{:propuestas => propuestas, :ronda => ronda} = estado
    estado = if r == ronda do
      propuestas = Map.put(propuestas, id, prop)
      %{estado | :propuestas => propuestas }
    else
      estado
    end
    send self(), :timeout_prop
    {:ok, estado}
  end

  def procesa_mensaje(:timeout_mins, estado) do
    %{:inicio_ronda => inicio} = estado
    t = :os.system_time(:millisecond)
    # Esperamos 100ms para recibir todos los mínimos antes de
    # decidir. En caso de que aún haya pasado un segundo, seguimos
    # esperando a recibir todos los mensajes con los mínimos.
    estado = if (t - inicio) > 1000 do
      consenso(%{estado | :decide => true})
    else
      send self(), :timeout_mins
      estado
    end
    {:ok, estado}
  end


  def procesa_mensaje({:id, id, :minimo, min, :ronda, r}, estado) do
    %{:minimos => minimos, :ronda => ronda} = estado
    estado = if r == ronda do
      minimos = Map.put(minimos, id, min)
      %{estado | :minimos => minimos}
    else
      estado
    end
    send self(), :timeout_mins
    {:ok, estado}
  end

  def procesa_mensaje({:fallido, fallido, :prob_fallo, prob}, estado) do
    estado = %{estado | :fallido => fallido, :prob_fallo => prob}
    {:ok, estado}
  end

  defp envio_al_menos_un_mensaje do
    (:rand.uniform(16) > 8)
  end

  def fallos(estado, ronda) do
    %{:vecinos => vecinos, :id => id, :prop => prop,
      :prob_fallo => prob} = estado
    # IO.puts "ID (#{id}): Posiblemente voy a morir D: Ronda: #{ronda}"
    if :rand.uniform() <= prob do
      if envio_al_menos_un_mensaje() do
        # IO.puts "ID (#{id}): Voy a morir en la ronda #{ronda}, pero al menos enviaré mi propuesta #{prop}"
        n = Enum.count(vecinos)
        random = :rand.uniform(n)
        new_vecs = vecinos |> Enum.shuffle |> Enum.take(random)
        # IO.inspect new_vecs, label: "ID (#{id}) vecinos"
        Enum.map(new_vecs, fn v -> send(v, {:id, id, :propuesta, prop, :ronda, ronda}) end)
      else
        # IO.puts "ID (#{id}): Muriendo sin haber amado en la ronda #{ronda}"
      end
      Process.exit(self(), :kill)
    else
      # IO.puts "Ok, al final no morí, así que envío mensaje a todos"
      Enum.map(vecinos, fn v -> send(v, {:id, id, :propuesta, prop, :ronda, ronda}) end)
    end
  end

  def consenso(estado) do
    %{:propuestas => propuestas, :prop => prop,
      :vecinos => vecinos, :ronda => ronda, :decide => decide,
      :continua => continua?, :id => id, :minimos => minimos,
      :envio_mensaje => envio?, :fallido => fallido?,
      :prop_recibidas => recibidas?, :min => min} = estado
    # Me muero en la simulación antes de enviar cualquier mensaje
    # Envíamos el mensaje una sola vez
    estado = if not envio? do
      ronda = ronda + 1
      inicio = :os.system_time(:millisecond)
      if fallido? do
        fallos(estado, ronda)
      else
        Enum.map(vecinos, fn v -> send(v, {:id, id, :propuesta, prop, :ronda, ronda}) end)
      end
      %{estado | :envio_mensaje => true, :ronda => ronda, :inicio_ronda => inicio}
    else
      estado
    end
    # Esperamos a que lleguen las propuestas
    estado = if continua? and not recibidas? do
      ronda = ronda + 1
      # Calculamos el mínimo
      propuestas = Map.put(propuestas, id, prop)
      # IO.inspect propuestas, label: "ID: #{id}, Las propuestas recibidas son, debe continuar #{continua?}"
      m = Enum.min(Map.values(propuestas))
      Enum.map(vecinos, fn v -> send(v, {:id, id, :minimo, m, :ronda, ronda}) end)
      inicio = :os.system_time(:millisecond)
      %{estado | :ronda => ronda, :inicio_ronda => inicio, :min => m,
                 :continua => false, :prop_recibidas => true}
    else
      estado
    end

    # Esperamos a que lleguen los mínimos
    if decide do
      # Calculamos la decisión
      # IO.inspect minimos, label: "ID: #{id}, Los mínimos recibidos son"
      minimos = Map.put(minimos, id, min)
      decision = Enum.min(Map.values(minimos))
      IO.puts("Soy el proceso #{id} y la decisión es: #{decision} en la ronda #{ronda}")
      Process.exit(self(), :kill) # Nos matamos después de decidir :P
    end
    estado
  end

end

# Iniciamos la ejecución con 8 procesos y uno que falla al inicio de
# la ejecución. Si queremos que falle desde el inicio, le envíamos el
# token :fallido con verdadero como parámetro, y :prob_fallo con el
# valor de la probabilidad de que falle dicho proceso.
a = spawn(Consenso1Falla, :inicio, [])
b = spawn(Consenso1Falla, :inicio, [])
c = spawn(Consenso1Falla, :inicio, [])
d = spawn(Consenso1Falla, :inicio, [])
e = spawn(Consenso1Falla, :inicio, [])
f = spawn(Consenso1Falla, :inicio, [])
g = spawn(Consenso1Falla, :inicio, [])
h = spawn(Consenso1Falla, :inicio, [])

send a, {:id, "a"}
send a, {:vecinos, [b, c, d, e, f, g, h]}
send a, {:prop, 1}
send a, {:fallido, true, :prob_fallo, 0.5}
send b, {:id, "b"}
send b, {:vecinos, [a, c, d, e, f, g, h]}
send b, {:prop, 2}
send c, {:id, "c"}
send c, {:vecinos, [a, b, d, e, f, g, h]}
send c, {:prop, 2}
send d, {:id, "d"}
send d, {:vecinos, [a, b, c, e, f, g, h]}
send d, {:prop, 2}
send e, {:id, "e"}
send e, {:vecinos, [a, b, c, d, f, g, h]}
send e, {:prop, 3}
send f, {:id, "f"}
send f, {:vecinos, [a, b, c, d, e, g, h]}
send f, {:prop, 3}
send g, {:id, "g"}
send g, {:vecinos, [a, b, c, d, e, f, h]}
send g, {:prop, 3}
send h, {:id, "h"}
send h, {:vecinos, [a, b, c, d, e, f, g]}
send h, {:prop, 4}
send a, {:inicia}
send b, {:inicia}
send c, {:inicia}
send d, {:inicia}
send e, {:inicia}
send f, {:inicia}
send g, {:inicia}
send h, {:inicia}
