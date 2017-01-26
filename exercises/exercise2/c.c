#include <pthread.h>
#include <stdio.h>

int i = 0;

pthread_mutex_t i_mutex = PTHREAD_MUTEX_INITIALIZER;

void* plus() {
    pthread_mutex_lock(&i_mutex);
    for (int j = 0; j < 100000; j++) {
        i++;
    }
    pthread_mutex_unlock(&i_mutex);
}

void* minus() {
    pthread_mutex_lock(&i_mutex);

    for (int j = 0; j < 80000; j++) {
        i--;
    }
    pthread_mutex_unlock(&i_mutex);
}

int main() {
    pthread_t min_thread;
    pthread_t plu_thread;

    pthread_mutex_init(&i_mutex, NULL);

    pthread_create(&plu_thread, NULL, plus, NULL);
    pthread_create(&min_thread, NULL, minus, NULL);

    pthread_join(min_thread, NULL);
    pthread_join(plu_thread, NULL);

    printf("Value of i: %d\n", i);
}
