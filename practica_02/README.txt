González Alvarado Raúl
313245312

a) ¿Qué diferencias encuentras entre la implementación realizada aquí y los algoritmos de clase?
  
  La principal diferencia es que la implementación de clase es de alto nivel, es decir que solo mencionamos muy por encima lo que se está haciendo.
  En cambio en nuestra implementación tenemos que hacer muy a detalle cada paso del algoritmo. Cómo ejemplo tenemos la sincronía: en el algoritmo
  suponemos que los mensajes llegan en una unidad de tiempo constante pero en la implementación tenemos que simular eso, ya que el lenguaje
  utilizado es asíncrono. Otro ejemplo es la elección de la propuesta más frecuente, en el algoritmo visto en clase solo se mencionaba literalmente:
  "valor que se repite más en propuestas", mientras que en la implementación tenemos que crear una función para implementar esa idea.

  A todo esto, también tenemos que utilizar variables que nunca se mencionan en el algoritmo visto en clase para simular varias propiedades
  del estado de cada proceso y así poder controlar su consistencia entre rondas y fases.  

  Como conclusión es que el algoritmo visto en clase es una abstracción para simplificar su estudio, pero para la implementación se vuelve un
  tanto más complicado. 

b) ¿Qué semejanzas hay?
  
  Sin tomar en cuenta las diferencias en cuanto implementación, los algoritmos siguen siendo los mismos, se siguen teniendo conjuntos para guardar
  las propociciones recibidas y flags para determinar ciertos estados de nuestros procesos.

c) Realiza una ejecución con n/4 < t < n/2 para el algoritmo de consenso bizantino. ¿Se pudo llegar a algún acuerdo? Describe la ejecución realizada.
  
  Aun que hay ocasiones en que sí llega a un acuerdo con dicha t, no siempre pasa, todo depende de como esté implementado el comportamiento de los 
  bizantinos.

  En una primera implementación el bizantino cambiaba la propuesta que tenía que enviar, pero aún así enviaba la misma a todos los procesos, con lo 
  cual siempre se llegaba a un acuerdo. Mi segunda implementación fué que los procesos bizantinos mandaran a cada proceso una propuesta diferente,
  asi logramos que cuando el proceso de la fase final sea un bizantino, y no se haya llegado a un acuerdo hasta ese momento, este les mande
  propuestas distintas a cada proceso y estos al ser la última etapa y no tener acuerdo por mayoría elijan la del proceso bizantino.
