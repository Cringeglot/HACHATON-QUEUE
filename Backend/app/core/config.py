#настройки пока условные
class QueueSettings:
    PRIORITY_PRE_REG: int = 100
    PRIORITY_QR: int = 50
    PRIORITY_LIVE: int = 10

    WAIT_TIME_MULTIPLIER: int = 2

     # формула что то типа: итоговый приоритет = 
     # = база + (модификатор времени * время ожидания)
     #чтобы очередь в лайве не стояла вечно