package main

import (
    "fmt"
    "os"
    "net/http"
    "runtime"
)

func main() {
    port := os.Getenv("PORT")
    http.HandleFunc("/", HelloServer)
    http.ListenAndServe(":" + port, nil)
}

func HelloServer(w http.ResponseWriter, r *http.Request) {
    message := os.Getenv("MESSAGE")
    architecture := runtime.GOARCH
    fmt.Fprintf(w, "%s %s\n", message, r.URL.Path[1:])
    fmt.Fprintf(w, "Architecture: %s\n", architecture)
}
