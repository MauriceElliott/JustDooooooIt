import Foundation

// MARK: - TodoItem
struct TodoItem: Codable {
    let id: UInt32
    let text: String
    let parentId: UInt32?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case text
        case parentId = "parent_id"
        case createdAt = "created_at"
    }
}

// MARK: - CompletedTask
struct CompletedTask: Codable {
    let id: UInt32
    let text: String
    let completedAt: String
    let hadSubtasks: Bool
    let subtaskCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case text
        case completedAt = "completed_at"
        case hadSubtasks = "had_subtasks"
        case subtaskCount = "subtask_count"
    }
}

// MARK: - TodoList
struct TodoList: Codable {
    var items: [String: TodoItem] = [:]
    var nextId: UInt32 = 1
    var completedCount: UInt32 = 0
    var completedHistory: [CompletedTask] = []
    
    enum CodingKeys: String, CodingKey {
        case items
        case nextId = "next_id"
        case completedCount = "completed_count"
        case completedHistory = "completed_history"
    }
    
    init() {
        self.items = [:]
        self.nextId = 1
        self.completedCount = 0
        self.completedHistory = []
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decode([String: TodoItem].self, forKey: .items)
        nextId = try container.decode(UInt32.self, forKey: .nextId)
        completedCount = try container.decodeIfPresent(UInt32.self, forKey: .completedCount) ?? 0
        completedHistory = try container.decodeIfPresent([CompletedTask].self, forKey: .completedHistory) ?? []
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
            parentId: parentId,
            createdAt: createdAt
        )
        
        items[String(id)] = item
        nextId += 1
        return id
    }
    
    mutating func completeItem(id: UInt32) -> (success: Bool, taskText: String, subtaskCount: Int) {
        guard let item = items[String(id)] else { 
            return (false, "", 0) 
        }
        
        let subItems = getSubItems(parentId: id)
        let subtaskCount = subItems.count
        let hadSubtasks = subtaskCount > 0
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        let completedAt = formatter.string(from: Date())
        
        let completedTask = CompletedTask(
            id: item.id,
            text: item.text,
            completedAt: completedAt,
            hadSubtasks: hadSubtasks,
            subtaskCount: subtaskCount
        )
        
        completedHistory.append(completedTask)
        completedCount += 1
        
        deleteItem(id: id)
        
        return (true, item.text, subtaskCount)
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
    
    mutating func renumberItems() {
        var oldToNewId: [UInt32: UInt32] = [:]
        var newItems: [String: TodoItem] = [:]
        var currentId: UInt32 = 1
        
        let rootItems = getRootItems()
        
        func renumberItemAndChildren(item: TodoItem, newParentId: UInt32?) {
            let newId = currentId
            oldToNewId[item.id] = newId
            currentId += 1
            
            let newItem = TodoItem(
                id: newId,
                text: item.text,
                parentId: newParentId,
                createdAt: item.createdAt
            )
            newItems[String(newId)] = newItem
            
            let children = getSubItems(parentId: item.id)
            for child in children {
                renumberItemAndChildren(item: child, newParentId: newId)
            }
        }
        
        for rootItem in rootItems {
            renumberItemAndChildren(item: rootItem, newParentId: nil)
        }
        
        items = newItems
        nextId = currentId
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
        print("\(indent)[\(item.id)] ○ \(item.text)")
        
        let subItems = getSubItems(parentId: item.id)
        for subItem in subItems {
            displayItem(item: subItem, indentLevel: indentLevel + 1)
        }
    }
    
    func displayStats() {
        print("📊 Completion Statistics:")
        print("Total completed: \(completedCount) tasks\n")
        
        if completedHistory.isEmpty {
            print("No completed tasks yet.")
            return
        }
        
        print("Recently completed:")
        let recentTasks = completedHistory.suffix(10).reversed()
        for task in recentTasks {
            let subtaskInfo = task.hadSubtasks ? " (\(task.subtaskCount) subtasks)" : ""
            print("[\(task.id)] ✓ \(task.text)\(subtaskInfo) (\(task.completedAt))")
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
    print("  jdi add <text>           Add a new todo (shorthand: a)")
    print("  jdi sub <id> <text>      Add a subtask (shorthand: s)")
    print("  jdi done <id>            Complete and archive todo (shorthand: d)")
    print("  jdi delete <id>          Delete todo without archiving (shorthand: del)")
    print("  jdi list                 List all todos (shorthand: l)")
    print("  jdi stats                Show completion statistics (shorthand: st)")
    print("  jdi help                 Show this help message (shorthand: h)")
}

func main() {
    let args = CommandLine.arguments
    
    guard args.count > 1 else {
        var todoList = loadTodoList()
        todoList.renumberItems()
        saveTodoList(todoList)
        todoList.display()
        return
    }
    
    let command = args[1]
    var todoList = loadTodoList()
    
    switch command {
    case "add", "a":
        guard args.count >= 3 else {
            print("Error: 'add' requires text")
            printUsage()
            return
        }
        
        let text = args[2...].joined(separator: " ")
        let id = todoList.addItem(text: text, parentId: nil)
        saveTodoList(todoList)
        print("Added todo \(id): \(text)")
        
    case "sub", "s":
        guard args.count >= 4 else {
            print("Error: 'sub' requires parent ID and text")
            print("Usage: jdi sub <parent_id> <text>")
            return
        }
        
        guard let parentId = UInt32(args[2]) else {
            print("Error: Invalid parent ID")
            return
        }
        
        guard todoList.items[String(parentId)] != nil else {
            print("Error: Parent todo \(parentId) does not exist")
            return
        }
        
        let text = args[3...].joined(separator: " ")
        let id = todoList.addItem(text: text, parentId: parentId)
        saveTodoList(todoList)
        print("Added subtask \(id) to [\(parentId)]: \(text)")
        
    case "done", "d":
        guard args.count == 3, let id = UInt32(args[2]) else {
            print("Error: 'done' requires a valid ID")
            printUsage()
            return
        }
        
        let result = todoList.completeItem(id: id)
        if result.success {
            saveTodoList(todoList)
            let subtaskInfo = result.subtaskCount > 0 ? " and \(result.subtaskCount) subtask(s)" : ""
            print("✓ Completed and removed todo \(id)\(subtaskInfo): \(result.taskText)")
        } else {
            print("Error: Todo \(id) not found")
        }
        
    case "delete", "del":
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
        
    case "list", "l":
        todoList.renumberItems()
        saveTodoList(todoList)
        todoList.display()
        
    case "stats", "st":
        todoList.displayStats()
        
    case "help", "--help", "-h", "h":
        printUsage()
        
    default:
        print("Error: Unknown command '\(command)'")
        printUsage()
    }
}

// Run the application
main()
