package main

import (
    "fmt"
    "os"
    "net/http"
)

func main() {
    port := os.Getenv("PORT")
    http.HandleFunc("/", HelloServer)
    http.ListenAndServe(":" + port, nil)
}

func HelloServer(w http.ResponseWriter, r *http.Request) {
    message := os.Getenv("MESSAGE")
    fmt.Fprintf(w, "%s %s", message, r.URL.Path[1:])
}

