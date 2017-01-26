#include <pthread.h>
#include <stdio.h>

int i = 0;

void* plus() {
    for (int j = 0; j < 100000; j++) {
        i++;
    }
}

void* minus() {
    for (int j = 0; j < 100000; j++) {
        i--;
    }
}

int main() {
    pthread_t min_thread;
    pthread_t plu_thread;
    pthread_create(&plu_thread, NULL, plus, NULL);
    pthread_create(&min_thread, NULL, minus, NULL);

    pthread_join(min_thread, NULL);
    pthread_join(plu_thread, NULL);

    printf("Value of i: %d\n", i);
}
