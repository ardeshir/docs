#### Create a C++ Script 
...that will walk all the files inside a /data directory and replace all blank spaces in filenames with under scores "_" ? 

In order to walk through all the files in a directory and rename the files in C++, you can use the "filesystem" library which is introduced in C++17. Here is a C++ snippet that will walk through all the files in a given directory, and rename all files with blank spaces in their names to have underscores instead. 

```cpp
#include <filesystem>
#include <string>
#include <algorithm>

namespace fs = std::filesystem;

int main()
{
    fs::path pathToData = "/data";
    
    for (auto& p : fs::recursive_directory_iterator(pathToData)) {
        if (p.path().filename().string().find(' ') != std::string::npos) {
            std::string oldname = p.path().string();
            std::string newname = oldname;
            std::replace(newname.begin(), newname.end(), ' ', '_'); // replace all ' ' to '_'
            
            fs::rename(oldname, newname);  // rename file
        }
    }

    return 0;
}
```

This code goes through all the files and directories recursively starting from /data directory. When it finds a filename that contains a space, it replaces all spaces with underscores and then renames the file.

Please keep in mind that std::filesystem is part of C++17 and later only, thus you will need a C++17 or later compliant compiler to compile this code.

Also be aware that this code has no error checking. In a production environment, you'd want to add checks for things like permissions issues when trying to rename a file.

Resource: https://en.cppreference.com/w/cpp/filesystem
