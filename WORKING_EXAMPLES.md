# TantivyEx Working Examples

This document provides **working examples** for the TantivyEx library. The quick start guide examples use string-based search which is currently broken. Use these Query API examples instead.

## ❌ What's Broken

String-based searches like these **don't work correctly**:
```elixir
# These return ALL documents regardless of search terms
{:ok, results} = Searcher.search(searcher, "elixir", 10)
{:ok, results} = Searcher.search(searcher, "title:phoenix", 10)
```

## ✅ What Works: Query API Examples

### Basic Setup

```elixir
alias TantivyEx.{Schema, Index, IndexWriter, Searcher, Query}

# Create schema
schema = Schema.new()
         |> Schema.add_text_field("title", :text_stored)
         |> Schema.add_text_field("content", :text_stored)
         |> Schema.add_text_field("author", :text_stored)
         |> Schema.add_text_field("tags", :text)
         |> Schema.add_u64_field("rating", :indexed_stored)
         |> Schema.add_text_field("category", :text_stored)

# Create index
{:ok, index} = Index.create_in_ram(schema)
{:ok, writer} = IndexWriter.new(index, 50_000_000)

# Add documents
documents = [
  %{
    "title" => "Getting Started with Elixir",
    "content" => "Elixir is a dynamic, functional language designed for building maintainable and scalable applications.",
    "author" => "Jane Doe",
    "tags" => "elixir programming functional",
    "rating" => 5,
    "category" => "Programming"
  },
  %{
    "title" => "Introduction to Phoenix Framework",
    "content" => "Phoenix is a web development framework written in Elixir. It provides high developer productivity.",
    "author" => "John Smith", 
    "tags" => "phoenix elixir web framework",
    "rating" => 4,
    "category" => "Web Development"
  },
  %{
    "title" => "Rust Performance Guide",
    "content" => "Rust is a systems programming language that runs blazingly fast and prevents segfaults.",
    "author" => "Bob Wilson",
    "tags" => "rust performance systems",
    "rating" => 4,
    "category" => "Systems Programming"
  }
]

# Index documents
Enum.each(documents, fn doc ->
  :ok = IndexWriter.add_document(writer, doc)
end)
:ok = IndexWriter.commit(writer)

# Create searcher
{:ok, searcher} = Searcher.new(index)
```

### 1. Term Search (Exact Match)

```elixir
# Search for documents with "elixir" in the title
{:ok, query} = Query.term(schema, "title", "elixir")
{:ok, results} = Searcher.search(searcher, query, 10)

# Results: Only documents with "elixir" in title
# [%{"title" => "Getting Started with Elixir", ...},
#  %{"title" => "Introduction to Phoenix Framework", ...}]
```

### 2. Search All Documents

```elixir
# Get all documents in the index
{:ok, query} = Query.all()
{:ok, results} = Searcher.search(searcher, query, 10)

# Results: All 3 documents
```

### 3. Search by Author

```elixir
# Find documents by a specific author
{:ok, query} = Query.term(schema, "author", "Jane Doe")
{:ok, results} = Searcher.search(searcher, query, 10)

# Results: Only documents by Jane Doe
```

### 4. Search by Rating

```elixir
# Find documents with rating 5
{:ok, query} = Query.term(schema, "rating", "5")
{:ok, results} = Searcher.search(searcher, query, 10)

# Results: Only documents with 5-star rating
```

### 5. Search by Category

```elixir
# Find programming-related documents
{:ok, query} = Query.term(schema, "category", "Programming")
{:ok, results} = Searcher.search(searcher, query, 10)

# Results: Only documents in Programming category
```

### 6. Boolean Queries

```elixir
# Create individual term queries
{:ok, elixir_query} = Query.term(schema, "title", "elixir") 
{:ok, phoenix_query} = Query.term(schema, "tags", "phoenix")

# OR query: documents that have "elixir" in title OR "phoenix" in tags
{:ok, or_query} = Query.boolean([], [elixir_query, phoenix_query], [])
{:ok, results} = Searcher.search(searcher, or_query, 10)

# AND query: documents that have both conditions
{:ok, and_query} = Query.boolean([elixir_query, phoenix_query], [], [])
{:ok, results} = Searcher.search(searcher, and_query, 10)
```

### 7. Search Only Document IDs

```elixir
# More efficient when you only need document IDs
{:ok, query} = Query.term(schema, "category", "Programming")
{:ok, doc_ids} = Searcher.search_ids(searcher, query, 10)

# Results: [0, 2] (document IDs)
```

### 8. Range Queries (for numeric fields)

```elixir
# Find documents with rating >= 4
{:ok, query} = Query.range(schema, "rating", 4, nil)
{:ok, results} = Searcher.search(searcher, query, 10)
```

## Complete Working Example

```elixir
defmodule TantivyExampleWorking do
  alias TantivyEx.{Schema, Index, IndexWriter, Searcher, Query}

  def run_search_example do
    # Setup
    schema = create_schema()
    {:ok, index} = Index.create_in_ram(schema)
    {:ok, writer} = IndexWriter.new(index, 50_000_000)
    
    # Add sample data
    add_sample_documents(writer)
    
    # Create searcher
    {:ok, searcher} = Searcher.new(index)
    
    # Perform searches
    search_examples(searcher, schema)
  end
  
  defp create_schema do
    Schema.new()
    |> Schema.add_text_field("title", :text_stored)
    |> Schema.add_text_field("content", :text_stored)
    |> Schema.add_text_field("author", :text_stored)
    |> Schema.add_u64_field("rating", :indexed_stored)
    |> Schema.add_text_field("category", :text_stored)
  end
  
  defp add_sample_documents(writer) do
    documents = [
      %{
        "title" => "Elixir Basics",
        "content" => "Learn the fundamentals of Elixir programming",
        "author" => "Jane Doe",
        "rating" => 5,
        "category" => "Programming"
      },
      %{
        "title" => "Phoenix Web Framework",
        "content" => "Building web applications with Phoenix",
        "author" => "John Smith",
        "rating" => 4,
        "category" => "Web Development"
      }
    ]
    
    Enum.each(documents, fn doc ->
      :ok = IndexWriter.add_document(writer, doc)
    end)
    
    :ok = IndexWriter.commit(writer)
  end
  
  defp search_examples(searcher, schema) do
    IO.puts("=== Search Examples ===")
    
    # Example 1: Find documents by title
    IO.puts("\n1. Search for 'Elixir' in title:")
    {:ok, query} = Query.term(schema, "title", "Elixir")
    {:ok, results} = Searcher.search(searcher, query, 10)
    print_results(results)
    
    # Example 2: Find documents by author  
    IO.puts("\n2. Search for author 'Jane Doe':")
    {:ok, query} = Query.term(schema, "author", "Jane Doe")
    {:ok, results} = Searcher.search(searcher, query, 10)
    print_results(results)
    
    # Example 3: Find high-rated documents
    IO.puts("\n3. Search for 5-star documents:")
    {:ok, query} = Query.term(schema, "rating", "5")
    {:ok, results} = Searcher.search(searcher, query, 10)
    print_results(results)
  end
  
  defp print_results(results) do
    IO.puts("Found #{length(results)} result(s):")
    Enum.with_index(results, 1) |> Enum.each(fn {result, idx} ->
      title = Map.get(result, "title", "No title")
      author = Map.get(result, "author", "No author")
      rating = Map.get(result, "rating", "No rating")
      IO.puts("  #{idx}. #{title} by #{author} (#{rating}⭐)")
    end)
  end
end

# Run the example
TantivyExampleWorking.run_search_example()
```

## Key Takeaways

1. **Always use the Query API** instead of string-based search
2. **Text fields need exact term matching** - "elixir" won't match "Elixir" 
3. **Numeric fields work well** with term queries using string values
4. **Boolean queries** allow complex search combinations
5. **Document content is properly retrieved** when using Query objects

## Run This Example

Save the complete example to a `.exs` file and run:

```bash
elixir -S mix run your_file.exs
```

This will demonstrate working search functionality with proper results filtering.