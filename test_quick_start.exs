# Quick Start Test for TantivyEx
# Testing the functionality described in the quick start guide

# Import the required modules
alias TantivyEx.{Schema, Index, IndexWriter, Searcher}

IO.puts("Starting TantivyEx Quick Start Test...")

# Step 1: Define Schema
IO.puts("1. Creating schema...")
schema = Schema.new()
         |> Schema.add_text_field("title", :text_stored)
         |> Schema.add_text_field("content", :text)
         |> Schema.add_text_field("author", :text_stored)
         |> Schema.add_text_field("tags", :text)
         |> Schema.add_u64_field("rating", :indexed_stored)
         |> Schema.add_text_field("category", :text_stored)
IO.puts("✓ Schema created successfully")

# Step 2: Create Index (in memory for testing)
IO.puts("2. Creating in-memory index...")
{:ok, index} = Index.create_in_ram(schema)
IO.puts("✓ Index created successfully")

# Step 3: Add Documents
IO.puts("3. Adding documents...")
{:ok, writer} = IndexWriter.new(index, 50_000_000)

blog_posts = [
  %{
    "title" => "Getting Started with Elixir",
    "content" => "Elixir is a dynamic, functional language designed for building maintainable and scalable applications. It leverages the Erlang Virtual Machine (BEAM), giving you a distributed, fault-tolerant system with hot code swapping.",
    "author" => "Jane Doe",
    "tags" => "elixir programming functional",
    "rating" => 5,
    "category" => "Programming"
  },
  %{
    "title" => "Introduction to Phoenix Framework",
    "content" => "Phoenix is a web development framework written in Elixir. It provides high developer productivity and high application performance. It uses the Model-View-Controller (MVC) pattern.",
    "author" => "John Smith",
    "tags" => "phoenix elixir web framework",
    "rating" => 4,
    "category" => "Web Development"
  },
  %{
    "title" => "Building Real-time Applications",
    "content" => "Phoenix provides built-in support for real-time features through Phoenix Channels. Channels use WebSockets and long polling to provide bidirectional communication between client and server.",
    "author" => "Alice Johnson",
    "tags" => "phoenix realtime websockets",
    "rating" => 5,
    "category" => "Real-time"
  },
  %{
    "title" => "Rust Performance Guide",
    "content" => "Rust is a systems programming language that runs blazingly fast, prevents segfaults, and guarantees memory safety. It's perfect for performance-critical applications.",
    "author" => "Bob Wilson",
    "tags" => "rust performance systems",
    "rating" => 4,
    "category" => "Systems Programming"
  },
  %{
    "title" => "Functional Programming in Elixir",
    "content" => "Elixir embraces the functional programming paradigm. Functions are first-class citizens, and immutability is the default. Pattern matching is one of the most powerful features.",
    "author" => "Carol Brown",
    "tags" => "elixir functional immutability",
    "rating" => 5,
    "category" => "Programming"
  }
]

Enum.each(blog_posts, fn post ->
  case IndexWriter.add_document(writer, post) do
    :ok -> nil
    error -> IO.puts("Error adding document: #{inspect(error)}")
  end
end)

case IndexWriter.commit(writer) do
  :ok -> IO.puts("✓ Documents added and committed successfully")
  error -> IO.puts("Error committing documents: #{inspect(error)}")
end

# Step 4: Create Searcher and Test Searches
IO.puts("4. Testing search functionality...")

{:ok, searcher} = Searcher.new(index)
IO.puts("✓ Searcher created successfully")

# Test different types of searches
searches = [
  {"elixir", "Simple text search for 'elixir'"},
  {"title:phoenix", "Field-specific search in title field"},
  {"phoenix", "Search for 'phoenix' across all fields"},
  {"functional", "Search for 'functional'"},
  {"author:\"Jane Doe\"", "Exact author search"},
  {"rust", "Search for 'rust'"},
  {"realtime", "Search for 'realtime'"},
  {"category:Programming", "Category-specific search"},
  {"rating:5", "Rating-specific search"},
  {"elixir AND functional", "Boolean AND search"},
  {"elixir OR rust", "Boolean OR search"},
  {"(elixir OR phoenix) AND rating:5", "Complex boolean query"}
]

Enum.each(searches, fn {query, description} ->
  IO.puts("\nTesting: #{description}")
  IO.puts("Query: #{query}")
  
  case Searcher.search(searcher, query, 10) do
    {:ok, results} ->
      IO.puts("✓ Search successful - Found #{length(results)} result(s)")
      if length(results) > 0 do
        Enum.with_index(results, 1) |> Enum.each(fn {result, idx} ->
          title = Map.get(result, "title", "No title")
          score = Map.get(result, "_score", "No score")
          IO.puts("  #{idx}. #{title} (score: #{score})")
        end)
      else
        IO.puts("  No results found")
      end
    {:error, error} ->
      IO.puts("✗ Search failed: #{inspect(error)}")
  end
end)

IO.puts("\n" <> String.duplicate("=", 50))
IO.puts("TantivyEx Quick Start Test Complete!")