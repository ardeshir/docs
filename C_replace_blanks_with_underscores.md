##### ANSI C Script 
...that will walk all the files inside a /data directory and replace all blank spaces in filenames with under scores "_" ? 

Sure, here is an example of a C program that uses the dirent.h and sys/stat.h libraries for accessing directories and files, and the string.h and stdlib.h libraries for manipulating strings. This program recursively walks all files in the "/data" directory and renames files, replacing blank spaces with underscores.

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>

void replace_spaces(char* path) {
    DIR* dir;
    struct dirent* ent;
    struct stat buf;
    char old_name[512];
    char new_name[512];
    char new_path[512];

    if ((dir = opendir(path)) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            sprintf(old_name, "%s/%s", path, ent->d_name);
            strcpy(new_name, ent->d_name);

            for(int i = 0; new_name[i]; i++){
                if(new_name[i] == ' ')
                    new_name[i] = '_';
            }

            if(strcmp(old_name, new_name) != 0) {
                sprintf(new_path, "%s/%s", path, new_name);
                rename(old_name, new_path);
            }

            // Check if the dir entry is a subdirectory.
            stat(new_path, &buf);
            if(S_ISDIR(buf.st_mode)){
                if(strcmp(ent->d_name, ".") != 0 && strcmp(ent->d_name, "..") != 0 ) {
                    replace_spaces(new_path);
                }
            }
        }
        closedir(dir);
    }
}

int main() {
    replace_spaces("/data");
    return 0;
}
```

Before executing this C program, you should have permission to access, read and modify files in the '/data' directory. Also, you should back up your data to avoid unwanted circumstances like data loss, because the rename operation is not reversible.

Tip: 'dirent.h' is not part of ANSI C, it is part of POSIX, but it is supported on many platforms, including UNIX, Linux and Windows (with MinGW or Cygwin). If you're working on Windows without such POSIX compatibility layers, you'll need to use the windows.h library and the FindFirstFile/FindNextFile functions.

Disclaimer: This is a simple C program and may not handle all edge cases. For production-level use, more comprehensive error checking and handling would be needed.
