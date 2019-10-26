defmodule ConsensoFallasBizantinas do

  ## Inicializamos el estado del proceso y comieza a recibir mensajes.
  def inicio do
    estado_inicial = %{
      ## Propuesta del proceso
      :prop => 0,

      ## Cota máxima de fallos en el sistema.
      :max_fallos => 0,

      ## Guardamos si es bizantino y cuál es la proba de mandar un mensaje bizantino.
      :bizantino => false,
      :prob_fallo_bizantino => 0,

      ## Flag para saber si se envió la proposición en la ronda.
      :mensaje_enviado => false,

      ## Guardamos la fase actual (1 to t+1) y la ronda actual (1 ó 2).
      :fase => 1,
      :ronda => nil,

      ## Propuestas recibidas en la ronda actual ,la propuesta más frecuente entre estas y
      ## la cantidad de apariciones de la proposición más frecuente.
      :propuestas => %{},
      :prop_mas_frecuente => nil,
      :cantidad_frecuente => 0,

      ## Guardamos cuándo inició la ronda de cada fase.
      :inicio_ronda_1 => nil,
      :inicio_ronda_2 => nil,

      ## Flags para saber si recibimos todos los mensajes de la ronda 1 y 2.
      :ronda_1_terminada => false,
      :ronda_2_terminada => false,

      ## Guardamos la propuesta que nos mandó el coordinador de la fase. 
      :prop_coord => nil
    }
    recibe_mensaje(estado_inicial)
  end

  ## Recibe todos los mensaje, los procesa según el tipo de mensaje que recibió y actualiza
  ## el estado.
  def recibe_mensaje(estado) do
    receive do
      mensaje ->
        {:ok, nuevo_estado} = procesa_mensaje(mensaje, estado)
        recibe_mensaje(nuevo_estado)
    end
  end

  ## Define el id del proceso por medio de un mensaje y lo agrega al estado.
  def procesa_mensaje({:id, id}, estado) do
    estado = Map.put(estado, :id, id)
    {:ok, estado}
  end

  ## Define los vecinos del proces por medio de un mensaje y lo agrega al estado.
  def procesa_mensaje({:vecinos, vecinos}, estado) do
    estado = Map.put(estado, :vecinos, vecinos)
    {:ok, estado}
  end

  ## Define la proposición inicial del proceso por medio de un mensaje y lo agrega al estado.
  def procesa_mensaje({:prop, prop}, estado) do
    estado = %{estado | :prop => prop}
    {:ok, estado}
  end

  ## Define la probabilidad de fallo del proceso por medio de un mensaje y lo agrega al estado.
  def procesa_mensaje({:bizantino, bizantino, :prob_fallo, prob}, estado) do
    estado = %{estado | :bizantino => bizantino, :prob_fallo_bizantino => prob}
    {:ok, estado}
  end

  ## Define la cantidad de procesos bizantinos que hay en el sistema.
  def procesa_mensaje({:max_fallos, t}, estado) do
    estado = %{estado | :max_fallos => t}
    {:ok, estado}
  end

  def procesa_mensaje({:inicia}, estado) do
    estado = consenso(estado)
    {:ok, estado}
  end

  def procesa_mensaje(:timeout_ronda_1, estado) do
    %{
      :inicio_ronda_1 => inicio,
      :ronda_1_terminada => ronda_terminada?
      } = estado
    t = :os.system_time(:millisecond)
    # Esperamos un segundo para recibir todos los mensajes que
    # recibimos. Y además verificamos que estemos en la ronda 1. 
    # En otro caso seguimos checando el tiempo transcurrido.
    estado = if (inicio != nil) and (t - inicio) > 1000 and not ronda_terminada? do
      consenso(%{estado | :ronda => :ronda_2, :ronda_1_terminada => true})
    else
      send self(), :timeout_ronda_1
      estado
    end
    {:ok, estado}
  end

  def procesa_mensaje({:id, id, :propuesta, prop, :fase, f, :ronda_1}, estado) do
    %{
      :propuestas => propuestas, 
      :fase => fase,
      :ronda => ronda,
      :id => mi_id
      } = estado

    estado = if ronda == :ronda_1 and fase == f do
      #IO.puts "ID (#{mi_id}): Agrego propuesta <#{id},#{prop},#{f},#{:ronda_1}>"
      propuestas = Map.put(propuestas, id, prop)
      %{estado | :propuestas => propuestas }
    else
      estado
    end
    send self(), :timeout_ronda_1
    {:ok, estado}
  end

  def procesa_mensaje(:timeout_ronda_2, estado) do
    %{
      :inicio_ronda_2 => inicio,
      :ronda_2_terminada => ronda_terminada?
      } = estado
    t = :os.system_time(:millisecond)
    # Esperamos 100ms para recibir todos los mínimos antes de
    # decidir. En caso de que aún haya pasado un segundo, seguimos
    # esperando a recibir todos los mensajes con los mínimos.
    estado = if (inicio != nil) and (t - inicio) > 1000  and not ronda_terminada? do
      consenso(%{estado | :ronda_2_terminada => true})
    else
      send self(), :timeout_ronda_2
      estado
    end
    {:ok, estado}
  end


  def procesa_mensaje({:id, id, :propuesta, prop, :fase, f, :ronda_2}, estado) do
    %{ 
      :ronda => ronda,
      :fase => fase,
      :id => mi_id
      } = estado

    estado = if ronda == :ronda_2 and fase == f do
      #IO.puts "ID (#{mi_id}): Prop coordinador <#{id},#{prop},#{f},#{:ronda_2}>"
      %{estado | :prop_coord => prop}
    else
      estado
    end
    send self(), :timeout_ronda_2
    {:ok, estado}
  end

  def fallos_bizantinos(estado, fase, ronda, proposicion \\ nil) do
    %{
      :id => id, 
      :prop => prop,
      :vecinos => vecinos, 
      :prob_fallo_bizantino => proba_fallo
      } = estado

    prop = proposicion || prop

    #IO.puts "(id:#{id}, fase:#{fase}, ronda:#{ronda}): Posiblemente mande mensajes incorrectos. Ronda: #{ronda}"
    if :rand.uniform() <= proba_fallo do
      fake_props = [1, 2, 4, 8, 16, 1024]
      #IO.puts "(id:#{id}, fase:#{fase}, ronda:#{ronda}): Voy a mandar un valor falso a cada proceso."
      Enum.map(
        vecinos, 
        fn v -> 
          fake_prop = fake_props |> Enum.shuffle |> Enum.at(0)
          send(v, {:id, id, :propuesta, fake_prop, :fase, fase, ronda}) 
        end)
    else
      #IO.puts "(id:#{id}, fase:#{fase}, ronda:#{ronda}): Voy a mandar un valor correcto #{prop}"
      Enum.map(vecinos, fn v -> send(v, {:id, id, :propuesta, prop, :fase, fase, ronda}) end)
    end
  end

  def consenso(estado) do
    %{
      :max_fallos => t,
      :mensaje_enviado => mensaje_enviado?,
      :propuestas => propuestas,
      :prop_mas_frecuente => prop_f,
      :cantidad_frecuente => num_prop_f,
      :prop => prop,
      :bizantino => bizantino?,
      :vecinos => vecinos, 
      :id => id,
      :fase => fase,
      :ronda => ronda,
      :ronda_1_terminada => r1_terminada?,
      :ronda_2_terminada => r2_terminada?,
      :prop_coord => prop_coord
      } = estado

    if fase <= (t + 1) do
      #IO.puts "(id:#{id}, fase:#{fase}, ronda:#{ronda}): Entrando a consenso"
      ## Enviamos el mensaje una sola vez, ya sea normal o como bizantino.
      estado = if not mensaje_enviado? do
        #IO.puts "ID (#{id}): No he enviado mi mensaje en la fase #{fase}"
        ronda = :ronda_1
        if bizantino? do
          #IO.puts "ID (#{id}): Soy bizantino >:3 en la fase #{fase}"
          fallos_bizantinos(estado, fase, ronda)
        else
          #IO.puts "ID (#{id}): No soy bizantino, voy a mandar mi propuesta #{prop} en la fase #{fase}"
          Enum.map(vecinos, fn v -> send(v, {
            :id, id, 
            :propuesta, prop, 
            :fase, fase, 
            ronda
            }) end)
        end
        inicio_r1 = :os.system_time(:millisecond)
        %{
          estado | 
          :mensaje_enviado => true,
          :fase => fase,
          :ronda => ronda,
          :inicio_ronda_1 => inicio_r1
        }
      else
        estado
      end

      # Esperamos a que lleguen las propuestas
      estado = if r1_terminada? and not r2_terminada? do
        #IO.puts "(id:#{id}, fase:#{fase}, ronda:#{ronda}): Entrando a la ronda 2"
        ronda = :ronda_2
        # Calculamos el mínimo
        propuestas = Map.put(propuestas, id, prop)
        #IO.inspect propuestas, label: "(id:#{id}, fase:#{fase}, ronda:#{ronda}): mis propuestas son"
        {prop_f, num_prop_f} = obtener_el_mas_frecuente(propuestas)
        #IO.puts "(id:#{id}, fase:#{fase}, ronda:#{ronda}): mas frecuente: #{prop_f}, tamaño: #{num_prop_f}"

        ## Manda mensaje si es lider de la fase.
        if id == fase do
        #IO.puts "(id:#{id}, fase:#{fase}, ronda:#{ronda}): Soy coordinador mando #{prop} a todos y a mi."
          if bizantino? do
            #IO.puts "(id:#{id}, fase:#{fase}, ronda:#{ronda}): Pero también soy bizantino >:3"
            fallos_bizantinos(estado, fase, ronda, prop_f)
          else
            Enum.map([self() | vecinos], fn v -> send(v, {
              :id, id, 
              :propuesta, prop_f, 
              :fase, fase, 
              ronda
              }) end)
          end
        end 

        inicio_r2 = :os.system_time(:millisecond)
        %{
          estado | 
          :ronda => ronda,
          :inicio_ronda_2 => inicio_r2, 
          :prop_mas_frecuente => prop_f,
          :cantidad_frecuente => num_prop_f
        }
      else
        estado
      end

      # Esperamos a que lleguen los mínimos
      if r1_terminada? and r2_terminada? do
        #IO.puts "(id:#{id}, fase:#{fase}, ronda:#{ronda}): ronda 1 y 2 de mensajes terminada."
        coord = prop_coord || prop
        prop = if num_prop_f > (Enum.count(vecinos) + 1) / 2 + t do
          prop_f
        else
          coord
        end

        #IO.puts "(id:#{id}, fase:#{fase}, ronda:#{ronda}): Mi prop de esta fase es #{prop}"
        ## Inicializamos el estado, pero guardamos fase, ronda
        ## y otros datos que no cambian entre fases.

        consenso(%{
          estado |
          :prop => prop,
          :mensaje_enviado => false,
          :propuestas => %{},
          :prop_mas_frecuente => nil,
          :cantidad_frecuente => 0,
          :inicio_ronda_1 => nil,
          :inicio_ronda_2 => nil,
          :ronda_1_terminada => false,
          :ronda_2_terminada => false,
          :prop_coord => nil,
          :fase => fase + 1
        })
      else
        estado
      end
    else
      IO.puts "Soy el proceso #{id} y la decisión es #{prop} despues de la fase #{fase - 1}"
      Process.exit(self(), :kill)
    end
  end

  def obtener_el_mas_frecuente propuestas do
    map_props = Enum.reduce(
      Map.to_list(propuestas), 
      %{}, 
      fn {k, v}, acc -> 
        ids = if Map.has_key?(acc, v) do acc[v] else [] end 
        Map.put(acc, v, [k | ids])
      end)
    Enum.reduce(
      Map.to_list(map_props),
      {:a, 0},
      fn {k, v}, {max_k, max_v} -> 
        if Enum.count(v) > max_v do
          {k, Enum.count(v)}
        else
          {max_k, max_v}
        end
      end)
  end

end

##########

t = 10

p1 = spawn(ConsensoFallasBizantinas, :inicio, [])
p2 = spawn(ConsensoFallasBizantinas, :inicio, [])
p3 = spawn(ConsensoFallasBizantinas, :inicio, [])
p4 = spawn(ConsensoFallasBizantinas, :inicio, [])
p5 = spawn(ConsensoFallasBizantinas, :inicio, [])
p6 = spawn(ConsensoFallasBizantinas, :inicio, [])
p7 = spawn(ConsensoFallasBizantinas, :inicio, [])
p8 = spawn(ConsensoFallasBizantinas, :inicio, [])
p9 = spawn(ConsensoFallasBizantinas, :inicio, [])
p10 = spawn(ConsensoFallasBizantinas, :inicio, [])
p11 = spawn(ConsensoFallasBizantinas, :inicio, [])
p12 = spawn(ConsensoFallasBizantinas, :inicio, [])
p13 = spawn(ConsensoFallasBizantinas, :inicio, [])
p14 = spawn(ConsensoFallasBizantinas, :inicio, [])
p15 = spawn(ConsensoFallasBizantinas, :inicio, [])
p16 = spawn(ConsensoFallasBizantinas, :inicio, [])
p17 = spawn(ConsensoFallasBizantinas, :inicio, [])
p18 = spawn(ConsensoFallasBizantinas, :inicio, [])
p19 = spawn(ConsensoFallasBizantinas, :inicio, [])
p20 = spawn(ConsensoFallasBizantinas, :inicio, [])
p21 = spawn(ConsensoFallasBizantinas, :inicio, [])
p22 = spawn(ConsensoFallasBizantinas, :inicio, [])
p23 = spawn(ConsensoFallasBizantinas, :inicio, [])
p24 = spawn(ConsensoFallasBizantinas, :inicio, [])
p25 = spawn(ConsensoFallasBizantinas, :inicio, [])
p26 = spawn(ConsensoFallasBizantinas, :inicio, [])
p27 = spawn(ConsensoFallasBizantinas, :inicio, [])
p28 = spawn(ConsensoFallasBizantinas, :inicio, [])
p29 = spawn(ConsensoFallasBizantinas, :inicio, [])
p30 = spawn(ConsensoFallasBizantinas, :inicio, [])

vecinos = [p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15, p16, p17, p18, p19, p20, p21, p22, p23, p24, p25, p26, p27, p28, p29, p30, ]

send p1, {:id, 1}
send p1, {:vecinos, List.delete(vecinos, p1)}
send p1, {:prop, 20}
send p1, {:max_fallos, t}
send p1, {:bizantino, true, :prob_fallo, 0.75}

send p2, {:id, 2}
send p2, {:vecinos, List.delete(vecinos, p2)}
send p2, {:prop, 20}
send p2, {:max_fallos, t}

send p3, {:id, 3}
send p3, {:vecinos, List.delete(vecinos, p3)}
send p3, {:prop, 20}
send p3, {:max_fallos, t}
send p1, {:bizantino, true, :prob_fallo, 0.3}

send p4, {:id, 4}
send p4, {:vecinos, List.delete(vecinos, p4)}
send p4, {:prop, 20}
send p4, {:max_fallos, t}

send p5, {:id, 5}
send p5, {:vecinos, List.delete(vecinos, p5)}
send p5, {:prop, 20}
send p5, {:max_fallos, t}
send p1, {:bizantino, true, :prob_fallo, 0.5}

send p6, {:id, 6}
send p6, {:vecinos, List.delete(vecinos, p6)}
send p6, {:prop, 20}
send p6, {:max_fallos, t}

send p7, {:id, 7}
send p7, {:vecinos, List.delete(vecinos, p7)}
send p7, {:prop, 15}
send p7, {:max_fallos, t}

send p8, {:id, 8}
send p8, {:vecinos, List.delete(vecinos, p8)}
send p8, {:prop, 22}
send p8, {:max_fallos, t}

send p9, {:id, 9}
send p9, {:vecinos, List.delete(vecinos, p9)}
send p9, {:prop, 12}
send p9, {:max_fallos, t}
send p1, {:bizantino, true, :prob_fallo, 0.9}

send p10, {:id, 10}
send p10, {:vecinos, List.delete(vecinos, p10)}
send p10, {:prop, 34}
send p10, {:max_fallos, t}
send p1, {:bizantino, true, :prob_fallo, 0.9}

send p11, {:id, 11}
send p11, {:vecinos, List.delete(vecinos, p11)}
send p11, {:prop, 67}
send p11, {:max_fallos, t}
send p1, {:bizantino, true, :prob_fallo, 0.9}

send p12, {:id, 12}
send p12, {:vecinos, List.delete(vecinos, p12)}
send p12, {:prop, 13}
send p12, {:max_fallos, t}
send p1, {:bizantino, true, :prob_fallo, 0.9}

send p13, {:id, 13}
send p13, {:vecinos, List.delete(vecinos, p13)}
send p13, {:prop, 22}
send p13, {:max_fallos, t}

send p14, {:id, 14}
send p14, {:vecinos, List.delete(vecinos, p14)}
send p14, {:prop, 22}
send p14, {:max_fallos, t}

send p15, {:id, 15}
send p15, {:vecinos, List.delete(vecinos, p15)}
send p15, {:prop, 1}
send p15, {:max_fallos, t}

send p16, {:id, 16}
send p16, {:vecinos, List.delete(vecinos, p16)}
send p16, {:prop, 22}
send p16, {:max_fallos, t}

send p17, {:id, 17}
send p17, {:vecinos, List.delete(vecinos, p17)}
send p17, {:prop, 28}
send p17, {:max_fallos, t}

send p18, {:id, 18}
send p18, {:vecinos, List.delete(vecinos, p18)}
send p18, {:prop, 3}
send p18, {:max_fallos, t}

send p19, {:id, 19}
send p19, {:vecinos, List.delete(vecinos, p19)}
send p19, {:prop, 20}
send p19, {:max_fallos, t}

send p20, {:id, 20}
send p20, {:vecinos, List.delete(vecinos, p20)}
send p20, {:prop, 23}
send p20, {:max_fallos, t}
send p1, {:bizantino, true, :prob_fallo, 0.75}

send p21, {:id, 21}
send p21, {:vecinos, List.delete(vecinos, p21)}
send p21, {:prop, 36}
send p21, {:max_fallos, t}

send p22, {:id, 22}
send p22, {:vecinos, List.delete(vecinos, p22)}
send p22, {:prop, 12}
send p22, {:max_fallos, t}

send p23, {:id, 23}
send p23, {:vecinos, List.delete(vecinos, p23)}
send p23, {:prop, 65}
send p23, {:max_fallos, t}

send p24, {:id, 24}
send p24, {:vecinos, List.delete(vecinos, p24)}
send p24, {:prop, 34}
send p24, {:max_fallos, t}

send p25, {:id, 25}
send p25, {:vecinos, List.delete(vecinos, p25)}
send p25, {:prop, 50}
send p1, {:bizantino, true, :prob_fallo, 0.9}

send p26, {:id, 26}
send p26, {:vecinos, List.delete(vecinos, p26)}
send p26, {:prop, 10}
send p26, {:max_fallos, t}

send p27, {:id, 27}
send p27, {:vecinos, List.delete(vecinos, p27)}
send p27, {:prop, 45}
send p27, {:max_fallos, t}

send p28, {:id, 28}
send p28, {:vecinos, List.delete(vecinos, p28)}
send p28, {:prop, 15}
send p28, {:max_fallos, t}

send p29, {:id, 29}
send p29, {:vecinos, List.delete(vecinos, p29)}
send p29, {:prop, 23}
send p29, {:max_fallos, t}

send p30, {:id, 30}
send p30, {:vecinos, List.delete(vecinos, p30)}
send p30, {:prop, 2}
send p30, {:max_fallos, t}
send p1, {:bizantino, true, :prob_fallo, 0.9}


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
send p21, {:inicia}
send p22, {:inicia}
send p23, {:inicia}
send p24, {:inicia}
send p25, {:inicia}
send p26, {:inicia}
send p27, {:inicia}
send p28, {:inicia}
send p29, {:inicia}
send p30, {:inicia}

IO.puts "\n  ========================================  "
IO.puts "  | Tarda un poco, espera por favor xD   |  "
IO.puts "  | Tiene 10 procesos bizantinos, este   |  "
IO.puts "  | cuando solo puede admitir a lo mas 7 |  "
IO.puts "  ========================================  \n"