from threading import Thread
from threading import Lock

i = 0
i_lock = Lock()


def min():
    global i
    i_lock.acquire()
    for x in range(10000000):
        i -= 1
    i_lock.release()
    
def plu():
    i_lock.acquire()
    global i
    for x in range(10000000):
        i += 1
    i_lock.release()

def main():
    min_T = Thread(target = min, args = (),)
    plu_T = Thread(target = plu, args = (),)

    min_T.start()
    plu_T.start()

    min_T.join()
    plu_T.join()

    print(i)

main()
