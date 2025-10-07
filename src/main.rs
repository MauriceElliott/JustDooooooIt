use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::PathBuf;

#[derive(Serialize, Deserialize, Clone, Debug)]
struct TodoItem {
    id: u32,
    text: String,
    completed: bool,
    parent_id: Option<u32>,
    created_at: String,
}

#[derive(Serialize, Deserialize, Default)]
struct TodoList {
    items: HashMap<u32, TodoItem>,
    next_id: u32,
}

impl TodoList {
    fn new() -> Self {
        Self {
            items: HashMap::new(),
            next_id: 1,
        }
    }

    fn add_item(&mut self, text: String, parent_id: Option<u32>) -> u32 {
        let id = self.next_id;
        let item = TodoItem {
            id,
            text,
            completed: false,
            parent_id,
            created_at: chrono::Utc::now().format("%Y-%m-%d %H:%M:%S").to_string(),
        };
        self.items.insert(id, item);
        self.next_id += 1;
        id
    }

    fn complete_item(&mut self, id: u32) -> bool {
        if let Some(item) = self.items.get_mut(&id) {
            item.completed = true;
            true
        } else {
            false
        }
    }

    fn uncomplete_item(&mut self, id: u32) -> bool {
        if let Some(item) = self.items.get_mut(&id) {
            item.completed = false;
            true
        } else {
            false
        }
    }

    fn delete_item(&mut self, id: u32) -> bool {
        // First, delete all sub-items
        let sub_items: Vec<u32> = self.items
            .values()
            .filter(|item| item.parent_id == Some(id))
            .map(|item| item.id)
            .collect();
        
        for sub_id in sub_items {
            self.delete_item(sub_id);
        }
        
        // Then delete the item itself
        self.items.remove(&id).is_some()
    }

    fn get_root_items(&self) -> Vec<&TodoItem> {
        let mut items: Vec<&TodoItem> = self.items
            .values()
            .filter(|item| item.parent_id.is_none())
            .collect();
        items.sort_by_key(|item| item.id);
        items
    }

    fn get_sub_items(&self, parent_id: u32) -> Vec<&TodoItem> {
        let mut items: Vec<&TodoItem> = self.items
            .values()
            .filter(|item| item.parent_id == Some(parent_id))
            .collect();
        items.sort_by_key(|item| item.id);
        items
    }

    fn display(&self) {
        let root_items = self.get_root_items();
        if root_items.is_empty() {
            println!("No todos found. Use 'todo add <text>' to add a new todo.");
            return;
        }

        for item in root_items {
            self.display_item(item, 0);
        }
    }

    fn display_item(&self, item: &TodoItem, indent_level: usize) {
        let indent = "  ".repeat(indent_level);
        let status = if item.completed { "✓" } else { "○" };
        println!("{}[{}] {} {}", indent, item.id, status, item.text);
        
        let sub_items = self.get_sub_items(item.id);
        for sub_item in sub_items {
            self.display_item(sub_item, indent_level + 1);
        }
    }
}

fn get_data_file() -> PathBuf {
    let mut path = dirs::home_dir().unwrap_or_else(|| PathBuf::from("."));
    path.push(".todo_cli.json");
    path
}

fn load_todos() -> TodoList {
    let file_path = get_data_file();
    if file_path.exists() {
        let contents = fs::read_to_string(&file_path).unwrap_or_default();
        serde_json::from_str(&contents).unwrap_or_else(|_| TodoList::new())
    } else {
        TodoList::new()
    }
}

fn save_todos(todos: &TodoList) {
    let file_path = get_data_file();
    let json = serde_json::to_string_pretty(todos).unwrap();
    fs::write(&file_path, json).expect("Failed to save todos");
}

fn print_help() {
    println!("Todo CLI - Simple command-line todo manager");
    println!();
    println!("USAGE:");
    println!("  todo [COMMAND] [ARGS]");
    println!();
    println!("COMMANDS:");
    println!("  list, ls              List all todos");
    println!("  add <text>            Add a new todo");
    println!("  sub <parent_id> <text> Add a sub-todo to an existing todo");
    println!("  done <id>             Mark a todo as completed");
    println!("  undone <id>           Mark a todo as not completed");
    println!("  delete, rm <id>       Delete a todo (and all its sub-todos)");
    println!("  help, --help, -h      Show this help message");
    println!();
    println!("EXAMPLES:");
    println!("  todo add \"Buy groceries\"");
    println!("  todo sub 1 \"Buy milk\"");
    println!("  todo done 2");
    println!("  todo delete 1");
}

fn main() {
    let args: Vec<String> = env::args().collect();
    
    if args.len() < 2 {
        let todos = load_todos();
        todos.display();
        return;
    }

    let mut todos = load_todos();
    let command = &args[1];

    match command.as_str() {
        "list" | "ls" => {
            todos.display();
        }
        "add" => {
            if args.len() < 3 {
                eprintln!("Error: Please provide text for the todo");
                eprintln!("Usage: todo add <text>");
                return;
            }
            let text = args[2..].join(" ");
            let id = todos.add_item(text.clone(), None);
            save_todos(&todos);
            println!("Added todo [{}]: {}", id, text);
        }
        "sub" => {
            if args.len() < 4 {
                eprintln!("Error: Please provide parent ID and text for the sub-todo");
                eprintln!("Usage: todo sub <parent_id> <text>");
                return;
            }
            let parent_id: u32 = match args[2].parse() {
                Ok(id) => id,
                Err(_) => {
                    eprintln!("Error: Invalid parent ID");
                    return;
                }
            };
            if !todos.items.contains_key(&parent_id) {
                eprintln!("Error: Parent todo with ID {} not found", parent_id);
                return;
            }
            let text = args[3..].join(" ");
            let id = todos.add_item(text.clone(), Some(parent_id));
            save_todos(&todos);
            println!("Added sub-todo [{}] under [{}]: {}", id, parent_id, text);
        }
        "done" => {
            if args.len() < 3 {
                eprintln!("Error: Please provide the ID of the todo to mark as done");
                eprintln!("Usage: todo done <id>");
                return;
            }
            let id: u32 = match args[2].parse() {
                Ok(id) => id,
                Err(_) => {
                    eprintln!("Error: Invalid todo ID");
                    return;
                }
            };
            if todos.complete_item(id) {
                save_todos(&todos);
                println!("Marked todo [{}] as completed", id);
            } else {
                eprintln!("Error: Todo with ID {} not found", id);
            }
        }
        "undone" => {
            if args.len() < 3 {
                eprintln!("Error: Please provide the ID of the todo to mark as not done");
                eprintln!("Usage: todo undone <id>");
                return;
            }
            let id: u32 = match args[2].parse() {
                Ok(id) => id,
                Err(_) => {
                    eprintln!("Error: Invalid todo ID");
                    return;
                }
            };
            if todos.uncomplete_item(id) {
                save_todos(&todos);
                println!("Marked todo [{}] as not completed", id);
            } else {
                eprintln!("Error: Todo with ID {} not found", id);
            }
        }
        "delete" | "rm" => {
            if args.len() < 3 {
                eprintln!("Error: Please provide the ID of the todo to delete");
                eprintln!("Usage: todo delete <id>");
                return;
            }
            let id: u32 = match args[2].parse() {
                Ok(id) => id,
                Err(_) => {
                    eprintln!("Error: Invalid todo ID");
                    return;
                }
            };
            if todos.delete_item(id) {
                save_todos(&todos);
                println!("Deleted todo [{}] and all its sub-todos", id);
            } else {
                eprintln!("Error: Todo with ID {} not found", id);
            }
        }
        "help" | "--help" | "-h" => {
            print_help();
        }
        _ => {
            eprintln!("Error: Unknown command '{}'", command);
            eprintln!("Use 'todo help' to see available commands");
        }
    }
}
