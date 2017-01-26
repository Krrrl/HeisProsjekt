from threading import Thread

i = 0

def min():
    global i
    for x in range(10000000):
        i -= 1
    
def plu():
    global i
    for x in range(10000000):
        i += 1

def main():
    min_T = Thread(target = min, args = (),)
    plu_T = Thread(target = plu, args = (),)

    min_T.start()
    plu_T.start()

    min_T.join()
    plu_T.join()

    print(i)

main()
