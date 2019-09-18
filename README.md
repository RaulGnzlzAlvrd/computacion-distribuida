### Práctica 1 (Tarea 3)
#### Computación Distribuida

> **Nombre y No. de cuenta:** 
>
> González Alvarado Raúl. (313245312)

##### Reporte.

El tiempo y los mensajes de todos los algoritmos no cambia, pero esto es sin considerar los mensajes que se mandan para inicializar cada proceso, ya que si se se estuviera contando entonces se están mandando 2n mensajes más los que ya mandaba el algoritmo. Esto se debe a que para inicializar todos los processo se manda un mensaje con el PID de los vecinos para cada algoritmo y a demás se le manda un mensaje de inicialización.