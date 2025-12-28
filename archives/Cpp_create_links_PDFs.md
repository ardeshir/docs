#### This C++ program does the same job as the C# program: it scans the "./data" directory for PDF files, sorts them in alphabetical order, generates an HTML file with links to each PDF file, and writes the HTML content to the "index.html" file.

The std::filesystem::directory_iterator class is used to iterate over the files in the directory. The filename and its extension are retrieved using the path::filename and path::extension methods, respectively.

The std::sort function is used to sort the filenames in alphabetical order. Then, the program opens the output file with std::ofstream and writes the HTML content to it.

Please ensure that your compiler supports C++17 to use the <filesystem> library. You can usually enable C++17 in your compiler's settings or by using the -std=c++17 or -std=gnu++17 flag.

```cpp
#include <fstream>
#include <iostream>
#include <string>
#include <vector>
#include <algorithm>
#include <filesystem>

int main() {
    const std::string dirPath = "./data";
    const std::string outputPath = "./index.html";

    // Check if the directory exists
    if (!std::filesystem::exists(dirPath)) {
        std::cout << "Directory '" << dirPath << "' does not exist.\n";
        return 1;
    }

    std::vector<std::string> pdfFiles;

    // Get pdf files
    for (const auto &entry : std::filesystem::directory_iterator(dirPath)) {
        if (entry.path().extension() == ".pdf") {
            pdfFiles.push_back(entry.path().filename().string());
        }
    }

    // Sort the file names in alphabetical order
    std::sort(pdfFiles.begin(), pdfFiles.end());

    std::ofstream outputFile;
    outputFile.open(outputPath);

    outputFile << "<html><title> PDF files</title>\n";
    outputFile << "<body>\n";
    outputFile << "<h1>List of ebooks</h1>\n";
    outputFile << "<ul>\n";

    // Create a list item for each pdf file
    for (const auto& pdfFile : pdfFiles) {
        std::string fileName = pdfFile;
        std::string linkText = fileName.substr(0, fileName.find_last_of(".")).replace(fileName.find("_"), 1, " "); // Replace underscores with spaces
        outputFile << "<li><a href=\"" << fileName << "\">" << linkText << "</a></li>\n";
    }

    outputFile << "</ul>\n";
    outputFile << "</body>\n";
    outputFile << "</html>\n";

    outputFile.close();

    std::cout << "Index.html has been created.\n";
    
    return 0;
}

```
