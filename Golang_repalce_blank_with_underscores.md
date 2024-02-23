#####Create a Golang script that will walk all the files inside a /data directory and replace all blank spaces in filenames with under scores "_" ? 

Sure, here's a simple script in Go which does that. This script uses the `filepath.Walk` function from the `path/filepath` package, to traverse through every file in the `/data` directory. For each file, it renames the file if it contains any space in its name by replacing all blank spaces with underscores using the `strings.Replace` function.

```go
package main

import (
    "os"
    "fmt"
    "path/filepath"
    "strings"
)

func main() {
    err := filepath.Walk("/data", func(path string, info os.FileInfo, err error) error {
        if err != nil {
            fmt.Printf("Error while traversing %q: %v\n", path, err)
            return err
        }
        if info.IsDir() {
            return nil
        }
        if strings.Contains(info.Name(), " ") {
            newFileName := strings.Replace(info.Name(), " ", "_", -1)
            oldFilePath := filepath.Join(filepath.Dir(path), info.Name())
            newFilePath := filepath.Join(filepath.Dir(path), newFileName)
            os.Rename(oldFilePath, newFilePath)
        }
        return nil
    })

    if err != nil {
        fmt.Printf("Error walking the path /data: %v\n", err)
        return
    }
}
```

Please replace "/data" with your actual absolute path where you want to rename your files.

Please be aware that this script doesn't handle filename collision. So, if `file_name.txt` and `file name.txt` both exist in the same folder, this can cause an issue.

Also, note that error handling here is very basic (just printing the error and stopping the program). Depending on the context where you want to use this script, you might want more sophisticated error handling. Make sure to always properly handle errors in production code. 

Reference: 
Go's official documentation https://golang.org/pkg/path/filepath/ 
and https://golang.org/pkg/os/ for file operations and https://golang.org/pkg/strings/ for strings operations.
