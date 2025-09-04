# TantivyEx GenServer Demo with In-Memory Search Service
#
# This demonstrates a production-ready search service using GenServer
# with add/delete document functionality and various query operations.
#
# Run with: elixir -S mix run search_service_demo.exs

defmodule SearchService do
  @moduledoc """
  A GenServer-based search service for TantivyEx with in-memory indexing.
  
  Provides a high-level API for:
  - Adding and deleting documents
  - Various search operations (simple, field-specific, boolean queries)
  - Index management and statistics
  """
  
  use GenServer
  
  alias TantivyEx.{Schema, Index, IndexWriter}
  alias TantivyEx.SearcherFixed, as: Searcher
  alias TantivyEx.Query
  
  # Client API
  
  @doc "Start the search service"
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc "Add a document to the search index"
  def add_document(doc) when is_map(doc) do
    GenServer.call(__MODULE__, {:add_document, doc})
  end
  
  @doc "Add multiple documents to the search index"
  def add_documents(docs) when is_list(docs) do
    GenServer.call(__MODULE__, {:add_documents, docs})
  end
  
  @doc "Delete a document by ID"
  def delete_document(doc_id) do
    GenServer.call(__MODULE__, {:delete_document, doc_id})
  end
  
  @doc "Simple text search across all fields"
  def search(query, limit \\ 10) do
    GenServer.call(__MODULE__, {:search, query, limit})
  end
  
  @doc "Search in a specific field"
  def search_field(field, term, limit \\ 10) do
    GenServer.call(__MODULE__, {:search_field, field, term, limit})
  end
  
  @doc "Boolean AND search"
  def search_and(terms, limit \\ 10) do
    GenServer.call(__MODULE__, {:search_and, terms, limit})
  end
  
  @doc "Boolean OR search"
  def search_or(terms, limit \\ 10) do
    GenServer.call(__MODULE__, {:search_or, terms, limit})
  end
  
  @doc "Get all documents"
  def get_all_documents(limit \\ 100) do
    GenServer.call(__MODULE__, {:get_all, limit})
  end
  
  @doc "Get search service statistics"
  def stats() do
    GenServer.call(__MODULE__, :stats)
  end
  
  @doc "Reset the index (clear all documents)"
  def reset() do
    GenServer.call(__MODULE__, :reset)
  end
  
  # Server Implementation
  
  defstruct [:schema, :index, :writer, :doc_count]
  
  @impl true
  def init(opts) do
    schema_fields = Keyword.get(opts, :schema_fields, default_schema_fields())
    
    case setup_index(schema_fields) do
      {:ok, schema, index, writer} ->
        state = %__MODULE__{
          schema: schema,
          index: index,
          writer: writer,
          doc_count: 0
        }
        {:ok, state}
      
      {:error, reason} ->
        {:stop, reason}
    end
  end
  
  @impl true
  def handle_call({:add_document, doc}, _from, state) do
    case IndexWriter.add_document(state.writer, doc) do
      :ok ->
        case IndexWriter.commit(state.writer) do
          :ok ->
            new_state = %{state | doc_count: state.doc_count + 1}
            {:reply, {:ok, :added}, new_state}
          error ->
            {:reply, error, state}
        end
      error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:add_documents, docs}, _from, state) do
    results = Enum.map(docs, fn doc ->
      IndexWriter.add_document(state.writer, doc)
    end)
    
    if Enum.all?(results, &(&1 == :ok)) do
      case IndexWriter.commit(state.writer) do
        :ok ->
          new_state = %{state | doc_count: state.doc_count + length(docs)}
          {:reply, {:ok, length(docs)}, new_state}
        error ->
          {:reply, error, state}
      end
    else
      failed_count = Enum.count(results, &(&1 != :ok))
      {:reply, {:error, "#{failed_count} documents failed to add"}, state}
    end
  end
  
  @impl true
  def handle_call({:delete_document, doc_id}, _from, state) do
    # Note: TantivyEx doesn't have direct document deletion by ID in this version
    # In a real implementation, you might need to rebuild the index or use
    # Tantivy's delete functionality if available
    {:reply, {:error, "Document deletion not implemented in this version"}, state}
  end
  
  @impl true
  def handle_call({:search, query_string, limit}, _from, state) do
    case create_searcher_and_search(state, query_string, limit) do
      {:ok, results} -> {:reply, {:ok, results}, state}
      error -> {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:search_field, field, term, limit}, _from, state) do
    query_string = "#{field}:#{term}"
    case create_searcher_and_search(state, query_string, limit) do
      {:ok, results} -> {:reply, {:ok, results}, state}
      error -> {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:search_and, terms, limit}, _from, state) do
    query_string = Enum.join(terms, " AND ")
    case create_searcher_and_search(state, query_string, limit) do
      {:ok, results} -> {:reply, {:ok, results}, state}
      error -> {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:search_or, terms, limit}, _from, state) do
    query_string = Enum.join(terms, " OR ")
    case create_searcher_and_search(state, query_string, limit) do
      {:ok, results} -> {:reply, {:ok, results}, state}
      error -> {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:get_all, limit}, _from, state) do
    case create_searcher_and_search(state, "*", limit) do
      {:ok, results} -> {:reply, {:ok, results}, state}
      error -> {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      document_count: state.doc_count,
      schema_fields: Schema.get_field_names(state.schema),
      index_type: "in_memory"
    }
    {:reply, {:ok, stats}, state}
  end
  
  @impl true
  def handle_call(:reset, _from, state) do
    # Create a new index to reset
    case setup_index(default_schema_fields()) do
      {:ok, schema, index, writer} ->
        new_state = %{state | 
          schema: schema,
          index: index, 
          writer: writer,
          doc_count: 0
        }
        {:reply, {:ok, :reset}, new_state}
      error ->
        {:reply, error, state}
    end
  end
  
  # Private Helper Functions
  
  defp default_schema_fields do
    [
      {"id", :u64, :indexed_stored},
      {"title", :text, :text_stored},
      {"content", :text, :text_stored},
      {"author", :text, :text_stored},
      {"category", :text, :text_stored},
      {"tags", :text, :text},
      {"rating", :u64, :indexed_stored},
      {"published_at", :text, :text_stored},
      {"price", :f64, :fast_stored}
    ]
  end
  
  defp setup_index(schema_fields) do
    try do
      # Create schema
      schema = Enum.reduce(schema_fields, Schema.new(), fn {name, type, options}, schema ->
        case type do
          :text -> Schema.add_text_field(schema, name, options)
          :u64 -> Schema.add_u64_field(schema, name, options)
          :f64 -> Schema.add_f64_field(schema, name, options)
          :bool -> Schema.add_bool_field(schema, name, options)
          :date -> Schema.add_date_field(schema, name, options)
        end
      end)
      
      # Create in-memory index
      {:ok, index} = Index.create_in_ram(schema)
      {:ok, writer} = IndexWriter.new(index, 50_000_000)
      
      {:ok, schema, index, writer}
    rescue
      e -> {:error, "Failed to setup index: #{inspect(e)}"}
    end
  end
  
  defp create_searcher_and_search(state, query_string, limit) do
    case Searcher.new(state.index) do
      {:ok, searcher} ->
        Searcher.search_with_schema(searcher, query_string, state.schema, limit)
      error ->
        error
    end
  end
end

# Demo Module with Sample Data
defmodule SearchServiceDemo do
  @moduledoc """
  Demonstration of the SearchService with sample data and various operations.
  """
  
  def run do
    IO.puts("🚀 Starting TantivyEx SearchService Demo")
    IO.puts(String.duplicate("=", 60))
    
    # Start the service
    {:ok, _pid} = SearchService.start_link()
    IO.puts("✅ SearchService started successfully")
    
    # Add sample data
    add_sample_data()
    
    # Demonstrate various search operations
    demonstrate_searches()
    
    # Show statistics
    show_statistics()
    
    IO.puts("\n🎉 Demo completed successfully!")
    IO.puts("You can now interact with the SearchService manually:")
    IO.puts("  SearchService.search(\"elixir\")")
    IO.puts("  SearchService.search_field(\"author\", \"Jane\")")
    IO.puts("  SearchService.search_and([\"elixir\", \"programming\"])")
  end
  
  defp add_sample_data do
    IO.puts("\n📚 Adding sample documents...")
    
    sample_docs = [
      %{
        "id" => 1,
        "title" => "Getting Started with Elixir",
        "content" => "Elixir is a dynamic, functional language designed for building maintainable and scalable applications. It leverages the Erlang Virtual Machine, giving you a distributed, fault-tolerant system.",
        "author" => "Jane Doe",
        "category" => "Programming",
        "tags" => "elixir functional programming beginner",
        "rating" => 5,
        "published_at" => "2024-01-15",
        "price" => 29.99
      },
      %{
        "id" => 2,
        "title" => "Phoenix Web Development",
        "content" => "Phoenix is a web development framework written in Elixir. It provides high developer productivity and application performance through real-time features.",
        "author" => "John Smith",
        "category" => "Web Development",
        "tags" => "phoenix elixir web framework realtime",
        "rating" => 4,
        "published_at" => "2024-02-10",
        "price" => 39.99
      },
      %{
        "id" => 3,
        "title" => "Rust Performance Guide",
        "content" => "Rust is a systems programming language that runs blazingly fast, prevents segfaults, and guarantees memory safety. Perfect for performance-critical applications.",
        "author" => "Alice Johnson",
        "category" => "Systems Programming",
        "tags" => "rust performance systems memory-safety",
        "rating" => 5,
        "published_at" => "2024-01-20",
        "price" => 49.99
      },
      %{
        "id" => 4,
        "title" => "Functional Programming Principles",
        "content" => "Learn the core principles of functional programming including immutability, pattern matching, and higher-order functions. Applicable to many languages.",
        "author" => "Bob Wilson",
        "category" => "Programming",
        "tags" => "functional programming theory principles",
        "rating" => 4,
        "published_at" => "2024-03-05",
        "price" => 34.99
      },
      %{
        "id" => 5,
        "title" => "Real-time Systems with Elixir",
        "content" => "Building distributed, fault-tolerant real-time systems using Elixir and OTP. Covers GenServers, supervision trees, and distributed architectures.",
        "author" => "Carol Brown",
        "category" => "Distributed Systems",
        "tags" => "elixir otp realtime distributed genserver",
        "rating" => 5,
        "published_at" => "2024-02-28",
        "price" => 44.99
      }
    ]
    
    case SearchService.add_documents(sample_docs) do
      {:ok, count} -> 
        IO.puts("✅ Added #{count} documents successfully")
      {:error, reason} -> 
        IO.puts("❌ Failed to add documents: #{reason}")
    end
  end
  
  defp demonstrate_searches do
    IO.puts("\n🔍 Demonstrating Search Operations")
    IO.puts(String.duplicate("-", 40))
    
    # Simple text search
    demo_search("Simple search for 'elixir':", fn ->
      SearchService.search("elixir")
    end)
    
    # Field-specific search
    demo_search("Search for author 'Jane':", fn ->
      SearchService.search_field("author", "Jane")
    end)
    
    # Category search
    demo_search("Search for Programming category:", fn ->
      SearchService.search_field("category", "Programming")
    end)
    
    # Boolean AND search
    demo_search("Boolean AND search 'elixir AND programming':", fn ->
      SearchService.search_and(["elixir", "programming"])
    end)
    
    # Boolean OR search
    demo_search("Boolean OR search 'rust OR phoenix':", fn ->
      SearchService.search_or(["rust", "phoenix"])
    end)
    
    # High-rating search
    demo_search("Search for 5-star rated content:", fn ->
      SearchService.search_field("rating", "5")
    end)
    
    # Search for real-time content
    demo_search("Search for 'realtime' content:", fn ->
      SearchService.search("realtime")
    end)
    
    # Price range search (simulated with individual price)
    demo_search("Search for items priced at $49.99:", fn ->
      SearchService.search("49.99")
    end)
  end
  
  defp demo_search(description, search_fn) do
    IO.puts("\n#{description}")
    
    case search_fn.() do
      {:ok, results} ->
        IO.puts("📊 Found #{length(results)} result(s):")
        
        Enum.with_index(results, 1) |> Enum.each(fn {result, idx} ->
          title = Map.get(result, "title", "No title")
          author = Map.get(result, "author", "Unknown author")
          category = Map.get(result, "category", "Uncategorized")
          rating = Map.get(result, "rating", 0)
          
          IO.puts("   #{idx}. #{title}")
          IO.puts("      👤 #{author} | 📂 #{category} | ⭐ #{rating}")
        end)
        
      {:error, reason} ->
        IO.puts("❌ Search failed: #{reason}")
    end
  end
  
  defp show_statistics do
    IO.puts("\n📈 Service Statistics")
    IO.puts(String.duplicate("-", 25))
    
    case SearchService.stats() do
      {:ok, stats} ->
        IO.puts("📄 Documents: #{stats.document_count}")
        IO.puts("🏷️  Schema fields: #{Enum.join(stats.schema_fields, ", ")}")
        IO.puts("💾 Index type: #{stats.index_type}")
        
      {:error, reason} ->
        IO.puts("❌ Failed to get stats: #{reason}")
    end
  end
end

# Interactive Helper Functions
defmodule SearchHelpers do
  @doc "Quick search helper"
  def q(term), do: SearchService.search(term)
  
  @doc "Search by author"
  def author(name), do: SearchService.search_field("author", name)
  
  @doc "Search by category"
  def category(cat), do: SearchService.search_field("category", cat)
  
  @doc "Get all documents"
  def all(), do: SearchService.get_all_documents()
  
  @doc "Show stats"
  def stats(), do: SearchService.stats()
end

# Run the demo
IO.puts("Loading TantivyEx SearchService Demo...")
SearchServiceDemo.run()

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("💡 Quick Commands Available:")
IO.puts("   SearchHelpers.q(\"search term\")     # Quick search")
IO.puts("   SearchHelpers.author(\"Jane\")       # Search by author")  
IO.puts("   SearchHelpers.category(\"Programming\") # Search by category")
IO.puts("   SearchHelpers.all()               # Get all documents")
IO.puts("   SearchHelpers.stats()             # Show statistics")
IO.puts("\n🎯 Try: SearchHelpers.q(\"functional\")")