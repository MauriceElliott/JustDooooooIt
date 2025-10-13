import Foundation

// MARK: - TodoItem
struct TodoItem: Codable {
    let id: UInt32
    let text: String
    var completed: Bool
    let parentId: UInt32?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case text
        case completed
        case parentId = "parent_id"
        case createdAt = "created_at"
    }
}

// MARK: - TodoList
struct TodoList: Codable {
    var items: [String: TodoItem] = [:]
    var nextId: UInt32 = 1
    
    enum CodingKeys: String, CodingKey {
        case items
        case nextId = "next_id"
    }
    
    init() {
        self.items = [:]
        self.nextId = 1
    }
    
    mutating func addItem(text: String, parentId: UInt32? = nil) -> UInt32 {
        let id = nextId
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        let createdAt = formatter.string(from: Date())
        
        let item = TodoItem(
            id: id,
            text: text,
            completed: false,
            parentId: parentId,
            createdAt: createdAt
        )
        
        items[String(id)] = item
        nextId += 1
        return id
    }
    
    mutating func completeItem(id: UInt32) -> Bool {
        guard var item = items[String(id)] else { return false }
        item.completed = true
        items[String(id)] = item
        return true
    }
    
    mutating func uncompleteItem(id: UInt32) -> Bool {
        guard var item = items[String(id)] else { return false }
        item.completed = false
        items[String(id)] = item
        return true
    }
    
    mutating func deleteItem(id: UInt32) -> Bool {
        // First, delete all sub-items
        let subItems = items.values.filter { $0.parentId == id }
        for subItem in subItems {
            deleteItem(id: subItem.id)
        }
        
        // Then delete the item itself
        return items.removeValue(forKey: String(id)) != nil
    }
    
    func getRootItems() -> [TodoItem] {
        let rootItems = items.values.filter { $0.parentId == nil }
        return rootItems.sorted { $0.id < $1.id }
    }
    
    func getSubItems(parentId: UInt32) -> [TodoItem] {
        let subItems = items.values.filter { $0.parentId == parentId }
        return subItems.sorted { $0.id < $1.id }
    }
    
    func display() {
        let rootItems = getRootItems()
        if rootItems.isEmpty {
            print("No todos found. Use 'jdi add <text>' to add a new todo.")
            return
        }
        
        for item in rootItems {
            displayItem(item: item, indentLevel: 0)
        }
    }
    
    func displayItem(item: TodoItem, indentLevel: Int) {
        let indent = String(repeating: "  ", count: indentLevel)
        let status = item.completed ? "✓" : "○"
        print("\(indent)[\(item.id)] \(status) \(item.text)")
        
        let subItems = getSubItems(parentId: item.id)
        for subItem in subItems {
            displayItem(item: subItem, indentLevel: indentLevel + 1)
        }
    }
}

// MARK: - File Management
func getConfigPath() -> String {
    let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? ""
    return "\(homeDir)"
}

func getTodoFilePath() -> String {
    return "\(getConfigPath())/.todo_cli.json"
}

func ensureConfigDirExists() throws {
    let configPath = getConfigPath()
    let fileManager = FileManager.default
    
    if !fileManager.fileExists(atPath: configPath) {
        try fileManager.createDirectory(atPath: configPath, withIntermediateDirectories: true, attributes: nil)
    }
}

func loadTodoList() -> TodoList {
    let filePath = getTodoFilePath()
    
    guard FileManager.default.fileExists(atPath: filePath) else {
        return TodoList()
    }
    
    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let todoList = try JSONDecoder().decode(TodoList.self, from: data)
        return todoList
    } catch {
        print("Error loading todos: \(error)")
        return TodoList()
    }
}

func saveTodoList(_ todoList: TodoList) {
    do {
        try ensureConfigDirExists()
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(todoList)
        
        let filePath = getTodoFilePath()
        try data.write(to: URL(fileURLWithPath: filePath))
    } catch {
        print("Error saving todos: \(error)")
    }
}

// MARK: - Command Line Interface
func printUsage() {
    print("Usage:")
    print("  jdi add <text> [--parent <id>]    Add a new todo")
    print("  jdi complete <id>                 Mark a todo as completed")
    print("  jdi uncomplete <id>               Mark a todo as not completed")
    print("  jdi delete <id>                   Delete a todo and its sub-todos")
    print("  jdi list                          List all todos")
    print("  jdi help                          Show this help message")
}

func main() {
    let args = CommandLine.arguments
    
    guard args.count > 1 else {
        var todoList = loadTodoList()
        todoList.display()
        return
    }
    
    let command = args[1]
    var todoList = loadTodoList()
    
    switch command {
    case "add":
        guard args.count >= 3 else {
            print("Error: 'add' requires text")
            printUsage()
            return
        }
        
        var text = ""
        var parentId: UInt32? = nil
        var i = 2
        
        while i < args.count {
            if args[i] == "--parent" || args[i] == "-p" {
                guard i + 1 < args.count, let id = UInt32(args[i + 1]) else {
                    print("Error: --parent requires a valid ID")
                    return
                }
                parentId = id
                i += 2
            } else {
                if !text.isEmpty { text += " " }
                text += args[i]
                i += 1
            }
        }
        
        if let parentId = parentId, todoList.items[String(parentId)] == nil {
            print("Error: Parent todo \(parentId) does not exist")
            return
        }
        
        let id = todoList.addItem(text: text, parentId: parentId)
        saveTodoList(todoList)
        print("Added todo \(id): \(text)")
        
    case "complete":
        guard args.count == 3, let id = UInt32(args[2]) else {
            print("Error: 'complete' requires a valid ID")
            printUsage()
            return
        }
        
        if todoList.completeItem(id: id) {
            saveTodoList(todoList)
            print("Completed todo \(id)")
        } else {
            print("Error: Todo \(id) not found")
        }
        
    case "uncomplete":
        guard args.count == 3, let id = UInt32(args[2]) else {
            print("Error: 'uncomplete' requires a valid ID")
            printUsage()
            return
        }
        
        if todoList.uncompleteItem(id: id) {
            saveTodoList(todoList)
            print("Uncompleted todo \(id)")
        } else {
            print("Error: Todo \(id) not found")
        }
        
    case "delete":
        guard args.count == 3, let id = UInt32(args[2]) else {
            print("Error: 'delete' requires a valid ID")
            printUsage()
            return
        }
        
        if todoList.deleteItem(id: id) {
            saveTodoList(todoList)
            print("Deleted todo \(id)")
        } else {
            print("Error: Todo \(id) not found")
        }
        
    case "list":
        todoList.display()
        
    case "help", "--help", "-h":
        printUsage()
        
    default:
        print("Error: Unknown command '\(command)'")
        printUsage()
    }
}

// Run the application
main()
