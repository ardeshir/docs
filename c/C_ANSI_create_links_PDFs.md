#### ANSI C, using POSIX functions available on macOS. However, ANSI C does not have built-in support for file globbing or string replacement, so we'll use POSIX functions for directory listing and manual string manipulation for replacing underscores. Note that this is more complex and less safe than equivalent programs in languages with higher-level string and file manipulation functions.

```c
#include <stdio.h>
#include <string.h>
#include <dirent.h>
#include <sys/types.h>
#include <sys/stat.h>

void replace_char(char *str, char find, char replace){
    for( ; *str != '\0'; ++str){
        if( *str == find )
            *str = replace;
    }
}

int main() {
    const char *dirPath = "./data";
    const char *outputPath = "./index.html";
    DIR *dir;
    struct dirent *ent;
    FILE *file;

    // Check if the directory exists
    struct stat info;
    if( stat( dirPath, &info ) != 0 ){
        printf( "cannot access '%s'\n", dirPath );
        return 1;
    } else if( info.st_mode & S_IFDIR ){  /* S_ISDIR() doesn't exist on my windows */
        printf( "'%s' is a directory\n", dirPath );
    } else {
        printf( "'%s' is no directory\n", dirPath );
        return 1;
    }

    // Open the output file
    file = fopen(outputPath, "w");
    if(file == NULL) {
        printf("Unable to open file %s", outputPath);
        return 1;
    }
    
    fprintf(file, "<html><title> PDF files</title>\n");
    fprintf(file, "<body>\n");
    fprintf(file, "<h1>List of ebooks</h1>\n");
    fprintf(file, "<ul>\n");

    // Open the directory
    if ((dir = opendir (dirPath)) != NULL) {
        // Print all the files and directories within directory
        while ((ent = readdir (dir)) != NULL) {
            // Check if the file extension is .pdf
            char *ext = strrchr(ent->d_name, '.');
            if(ext != NULL && strcmp(ext, ".pdf") == 0) {
                char linkText[255];
                strncpy(linkText, ent->d_name, ext - ent->d_name);
                linkText[ext - ent->d_name] = '\0';
                replace_char(linkText, '_', ' ');

                fprintf(file, "<li><a href=\"%s\">%s</a></li>\n", ent->d_name, linkText);
            }
        }
        closedir (dir);
    } else {
        // Could not open directory
        perror ("");
        return 1;
    }

    fprintf(file, "</ul>\n");
    fprintf(file, "</body>\n");
    fprintf(file, "</html>\n");

    fclose(file);
    printf("index.html has been created.\n");

    return 0;
}

```
This program uses opendir and readdir to read the files in the directory. It checks each file to see if it ends with ".pdf", and if so, it generates a link for that file. The replace_char function is used to replace underscores with spaces in the link text.

Please note that this code does not sort the files. Sorting strings in C is non-trivial because C does not have a built-in dynamic array or string list type. If you need the files to be sorted, you would need to add all filenames to a dynamic data structure (such as a linked list or a dynamically resizing array), sort that data structure, and then generate the links in sorted order. This would make the program significantly more complex.
