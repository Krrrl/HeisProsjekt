package main

import (
    . "fmt"
    "runtime"
    "time"
)

func min() {
    for j:= 0; j < 100000; j++ {
        shared--
    }
}


func plu() {
    for j:= 0; j < 100000; j++ {
        shared++
    }
}

var shared int = 0

func main() {
    runtime.GOMAXPROCS(runtime.NumCPU())

    go min()
    go plu()

    time.Sleep(100*time.Millisecond)
    Println(shared)
}

