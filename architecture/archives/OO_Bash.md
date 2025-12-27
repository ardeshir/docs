# Object Oriented Bash 
---

## **📚 Design Philosophy and Architecture**

This project employs a disciplined approach to Bash scripting, leveraging established software design patterns and strict coding conventions. This structure ensures **clarity, robustness, and ease of maintenance** across all scripts.

---

## **1\. Core Architectural Pattern: Singleton-as-Facade**

Every executable script is built as a **Singleton-as-Facade**, which dictates how users interact with the tool and how the logic is organized.

* **The Script as a Singleton:** The script itself runs as a single, unique instance, responsible for managing its specific domain of tasks (e.g., database, networking, provisioning). This ensures **consistent state** and a single source of truth for that functionality.  
* **The CLI as a Facade:** The command-line flags (e.g., \--backup, \--cleanup) serve as the **simplified interface** (the Facade). Users interact only with these high-level flags, completely shielded from the complex, underlying functions and system commands (the subsystem).  
* **Layered Subsystems:** Complex tasks are delegated. A primary script (High-level Facade) may call a more specialized script (Lower-level Facade) to break down functionality and enforce **separation of concerns**.

---

## **2\. Script Lifecycle Management**

All scripts adhere to a predictable execution lifecycle using dedicated functions for setup and teardown, ensuring system hygiene and reliability.

### **A. Initialization (\_init())**

This function is the mandatory, **single entry point** for all pre-execution setup. It is the first internal function called by the script's main dispatcher.

* **Purpose:** Dependency checking, configuration loading, environment variable validation, and required resource setup.

### **B. Cleanup (\_cleanup())**

This function is executed right before the script terminates (often via a trap on exit signals) to manage teardown.

* **Purpose:** **Good System Citizenship**. It is responsible for removing all temporary files, clearing temporary directories, and explicitly **unsetting all PUBLIC scoped variables** to prevent environment pollution.

### **C. Robust Error Handling (Log, Don't Die)**

Scripts prioritize logging detailed error information (to STDOUT/STDERR) over immediate termination.

* **Goal:** Maintain system resilience. Non-critical errors are logged, and the script continues processing if logic allows. Only fatal errors trigger a controlled exit, guaranteeing the \_cleanup() routine runs.

---

## **3\. Coding and Scoping Principles**

We enforce strict coding practices based on functional principles to ensure predictable code behavior.

### **A. Functional Paradigm**

All core logic is implemented within named functions. The main script body is reserved solely for parsing CLI arguments and acting as the **dispatcher** to call the appropriate functional logic.

### **B. Strict Variable Scoping**

To prevent data contamination and ensure clear state tracking:

* **Public Global Variables:** Variables intended to store script state, configuration, or share data across functions **must be declared at the top of the script**, outside of any function.  
* **Local Function Variables:** Variables used only within a function **must be explicitly declared with the local keyword** before their first assignment. This prevents accidental namespace pollution of the public global scope.