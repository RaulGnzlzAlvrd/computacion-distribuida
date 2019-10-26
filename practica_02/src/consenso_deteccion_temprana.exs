defmodule ConsensoDeteccionTemprana do
  def inicio do
    estado_inicial = %{
      :prop => 0, 
      :vista => %{}, 
      :envio_mensaje => false,
      :fallido => false, 
      :ronda => 0, 
      :continua => false,
      :inicio_ronda => nil, 
      :prob_fallo => 0, 
      :cambio_ronda => false,
      :flags => %{},
      :flag => false,
      :rec_ant => nil,
      :rec_act => nil
    }
    recibe_mensaje(estado_inicial)
  end

  def recibe_mensaje(estado) do
    receive do
      mensaje ->
        {:ok, nuevo_estado} = procesa_mensaje(mensaje, estado)
        recibe_mensaje(nuevo_estado)
    end
  end

  def procesa_mensaje({:nodos_totales, n}, estado) do
    estado = %{estado | :rec_ant => n, :rec_act => n}
    {:ok, estado}
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

  def procesa_mensaje({:t, t}, estado) do
    estado = Map.put(estado, :t, t)
    {:ok, estado}
  end

  def procesa_mensaje({:fallido, fallido, :prob_fallo, prob}, estado) do
    estado = %{estado | :fallido => fallido, :prob_fallo => prob}
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

  def procesa_mensaje({:id, id, :prop, prop, :ronda, r, :flag, flag}, estado) do
    # Agregamos los mensajes si son de la ronda en la que estamos
    %{:vista => vista, :ronda => ronda, :flags => flags} = estado
    estado = if r == ronda do
      vista = Map.put(vista, id, prop)
      flags = Map.put(flags, id, flag)
      %{estado | :vista => vista, :flags => flags}
    else
      estado
    end
    send self(), {:timeout_prop, r}
    {:ok, estado}
  end

  defp envio_al_menos_un_mensaje do
    (:rand.uniform(16) > 8)
  end

  defp fallos(estado) do
    %{
      :vecinos => vecinos, 
      :id => id, 
      :prop => prop, 
      :prob_fallo => prob,
      :ronda => ronda,
      :flag => flag
      } = estado
    if :rand.uniform() <= prob do
      if envio_al_menos_un_mensaje() do
        IO.puts "ID (#{id}): Voy a morir en la ronda #{ronda}, pero al menos enviaré algún mensaje"
        n = Enum.count(vecinos)
        random = :rand.uniform(n)
        new_vecs = vecinos |> Enum.shuffle |> Enum.take(random)
        Enum.map(new_vecs, fn v -> send v, {:id, id, :prop, prop, :ronda, ronda, :flag, flag} end)
      else
        IO.puts "ID (#{id}): Muriendo sin haber amado en la ronda #{ronda}"
      end
      Process.exit(self(), :kill)
    end

  end

  def consenso(estado) do
    %{
      :vista => vista, 
      :flags => flags,
      :flag => flag,
      :rec_ant => rec_ant,
      :vecinos => vecinos,
      :continua => continua?, 
      :id => id, 
      :prop => prop,
      :envio_mensaje => envio?, 
      :fallido => fallido?,
      :ronda => ronda, 
      :t => t
      } = estado
    inicio = :os.system_time(:millisecond)
    if ronda < (t + 1) do
      estado = if not envio? do
        if fallido? do
          fallos(estado)# Simulamos fallos aleatorios
        else # Envíamos nuestros mensajes normalmente
          Enum.map(vecinos, fn v -> send v, {:id, id, :prop, prop, :ronda, ronda, :flag, flag} end)
        end
        %{estado | :envio_mensaje => true, :inicio_ronda => inicio}
      else
        estado
      end

      if flag do 
        # Mostramos la decisión
        IO.puts "Soy el proceso #{id} y la decisión es #{prop} en la ronda #{ronda}"
        Process.exit(self(), :kill)
      end

      # Esperamos a recuperar los mensajes
      if continua? do
        vista = Map.put(vista, id, prop)
        flags = Map.put(flags, id, flag)
        d = Enum.reduce(Map.values(flags), false, fn f, acc -> acc or f end) 
        min = Enum.min(Map.values(vista))
        rec_act = map_size(vista)
        flag = if (rec_ant == rec_act) || d do
          true
        else
          false
        end
        %{
          estado | 
          :flag => flag,
          :rec_act => rec_act,
          :rec_ant => rec_act,
          :envio_mensaje => false, 
          :continua => false,
          :prop => min, 
          :ronda => (ronda + 1), 
          :cambio_ronda => false,
          :vista => %{},
          :flags => %{}
        }
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

p1 = spawn(ConsensoDeteccionTemprana, :inicio, [])
p2 = spawn(ConsensoDeteccionTemprana, :inicio, [])
p3 = spawn(ConsensoDeteccionTemprana, :inicio, [])
p4 = spawn(ConsensoDeteccionTemprana, :inicio, [])
p5 = spawn(ConsensoDeteccionTemprana, :inicio, [])
p6 = spawn(ConsensoDeteccionTemprana, :inicio, [])
p7 = spawn(ConsensoDeteccionTemprana, :inicio, [])
p8 = spawn(ConsensoDeteccionTemprana, :inicio, [])
p9 = spawn(ConsensoDeteccionTemprana, :inicio, [])
p10 = spawn(ConsensoDeteccionTemprana, :inicio, [])
p11 = spawn(ConsensoDeteccionTemprana, :inicio, [])
p12 = spawn(ConsensoDeteccionTemprana, :inicio, [])
p13 = spawn(ConsensoDeteccionTemprana, :inicio, [])
p14 = spawn(ConsensoDeteccionTemprana, :inicio, [])
p15 = spawn(ConsensoDeteccionTemprana, :inicio, [])
p16 = spawn(ConsensoDeteccionTemprana, :inicio, [])
p17 = spawn(ConsensoDeteccionTemprana, :inicio, [])
p18 = spawn(ConsensoDeteccionTemprana, :inicio, [])
p19 = spawn(ConsensoDeteccionTemprana, :inicio, [])
p20 = spawn(ConsensoDeteccionTemprana, :inicio, [])


send p1, {:id, "p1"}
send p1, {:t, 10}
send p1, {:nodos_totales, 20}
send p1, {:prop, 1}
send p1, {:vecinos, [p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16, p17, p18, p19, p20]}
send p1, {:fallido, true, :prob_fallo, 0.1}

send p2, {:id, "p2"}
send p2, {:t, 10}
send p2, {:nodos_totales, 20}
send p2, {:prop, 2}
send p2, {:vecinos, [p1, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16, p17, p18, p19, p20]}
send p2, {:fallido, true, :prob_fallo, 0.5}

send p3, {:id, "p3"}
send p3, {:t, 10}
send p3, {:nodos_totales, 20}
send p3, {:prop, 3}
send p3, {:vecinos, [p1, p2, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16, p17, p18, p19, p20]}
send p3, {:fallido, true, :prob_fallo, 0.9}

send p4, {:id, "p4"}
send p4, {:t, 10}
send p4, {:nodos_totales, 20}
send p4, {:prop, 4}
send p4, {:vecinos, [p1, p2, p3, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16, p17, p18, p19, p20]}
send p4, {:fallido, true, :prob_fallo, 0.7}

send p5, {:id, "p5"}
send p5, {:t, 10}
send p5, {:nodos_totales, 20}
send p5, {:prop, 5}
send p5, {:vecinos, [p1, p2, p3, p4, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16, p17, p18, p19, p20]}

send p6, {:id, "p6"}
send p6, {:t, 10}
send p6, {:nodos_totales, 20}
send p6, {:prop, 6}
send p6, {:vecinos, [p1, p2, p3, p4, p5, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16, p17, p18, p19, p20]}

send p7, {:id, "p7"}
send p7, {:t, 10}
send p7, {:nodos_totales, 20}
send p7, {:prop, 7}
send p7, {:vecinos, [p1, p2, p3, p4, p5, p6, p8, p9, p10, p11, p12, p13, p14, p15, p16, p17, p18, p19, p20]}
send p7, {:fallido, true, :prob_fallo, 0.1}

send p8, {:id, "p8"}
send p8, {:t, 10}
send p8, {:nodos_totales, 20}
send p8, {:prop, 8}
send p8, {:vecinos, [p1, p2, p3, p4, p5, p6, p7, p9, p10, p11, p12, p13, p14, p15, p16, p17, p18, p19, p20]}
send p8, {:fallido, true, :prob_fallo, 0.2}

send p9, {:id, "p9"}
send p9, {:t, 10}
send p9, {:nodos_totales, 20}
send p9, {:prop, 9}
send p9, {:vecinos, [p1, p2, p3, p4, p5, p6, p7, p8, p10, p11, p12, p13, p14, p15, p16, p17, p18, p19, p20]}
send p9, {:fallido, true, :prob_fallo, 0.3}

send p10, {:id, "p10"}
send p10, {:t, 10}
send p10, {:nodos_totales, 20}
send p10, {:prop, 10}
send p10, {:vecinos, [p1, p2, p3, p4, p5, p6, p7, p8, p9, p11, p12, p13, p14, p15, p16, p17, p18, p19, p20]}

send p11, {:id, "p11"}
send p11, {:t, 10}
send p11, {:nodos_totales, 20}
send p11, {:prop, 11}
send p11, {:vecinos, [p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p12, p13, p14, p15, p16, p17, p18, p19, p20]}

send p12, {:id, "p12"}
send p12, {:t, 10}
send p12, {:nodos_totales, 20}
send p12, {:prop, 12}
send p12, {:vecinos, [p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p13, p14, p15, p16, p17, p18, p19, p20]}

send p13, {:id, "p13"}
send p13, {:t, 10}
send p13, {:nodos_totales, 20}
send p13, {:prop, 13}
send p13, {:vecinos, [p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p14, p15, p16, p17, p18, p19, p20]}
send p13, {:fallido, true, :prob_fallo, 0.8}

send p14, {:id, "p14"}
send p14, {:t, 10}
send p14, {:nodos_totales, 20}
send p14, {:prop, 14}
send p14, {:vecinos, [p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p15, p16, p17, p18, p19, p20]}
send p14, {:fallido, true, :prob_fallo, 0.3}

send p15, {:id, "p15"}
send p15, {:t, 10}
send p15, {:nodos_totales, 20}
send p15, {:prop, 15}
send p15, {:vecinos, [p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p16, p17, p18, p19, p20]}

send p16, {:id, "p16"}
send p16, {:t, 10}
send p16, {:nodos_totales, 20}
send p16, {:prop, 16}
send p16, {:vecinos, [p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p17, p18, p19, p20]}

send p17, {:id, "p17"}
send p17, {:t, 10}
send p17, {:nodos_totales, 20}
send p17, {:prop, 17}
send p17, {:vecinos, [p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16, p18, p19, p20]}
send p17, {:fallido, true, :prob_fallo, 0.6}

send p18, {:id, "p18"}
send p18, {:t, 10}
send p18, {:nodos_totales, 20}
send p18, {:prop, 18}
send p18, {:vecinos, [p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16, p17, p19, p20]}

send p19, {:id, "p19"}
send p19, {:t, 10}
send p19, {:nodos_totales, 20}
send p19, {:prop, 19}
send p19, {:vecinos, [p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16, p17, p18, p20]}

send p20, {:id, "p20"}
send p20, {:t, 10}
send p20, {:nodos_totales, 20}
send p20, {:prop, 20}
send p20, {:vecinos, [p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16, p17, p18, p19]}

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
send p14, {:inicia}
send p15, {:inicia}
send p16, {:inicia}
send p17, {:inicia}
send p18, {:inicia}
send p19, {:inicia}
send p20, {:inicia}
