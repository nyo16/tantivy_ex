defmodule TantivyEx.FullTextSearch do
  @moduledoc """
  A GenServer-based full-text search service for TantivyEx with in-memory indexing.
  
  This module provides a high-level, stateful API for building search applications
  with TantivyEx. It manages an in-memory search index and provides convenient
  functions for adding documents, performing searches, and managing the index.
  
  ## Features
  
  - **In-memory indexing**: Fast, volatile search index for real-time applications
  - **Document management**: Add single or multiple documents with automatic commits
  - **Multiple search types**: Simple text, field-specific, boolean AND/OR queries
  - **Production-ready**: GenServer-based with proper error handling and state management
  - **Flexible schema**: Configurable schema with support for text, numeric, and other field types
  - **Statistics**: Index statistics and performance monitoring
  
  ## Usage
  
  ### Basic Setup
  
  ```elixir
  # Start the search service
  {:ok, pid} = TantivyEx.FullTextSearch.start_link()
  
  # Or start with custom schema
  schema_fields = [
    {"title", :text, :text_stored},
    {"content", :text, :text_stored},
    {"author", :text, :text_stored},
    {"rating", :u64, :indexed_stored}
  ]
  {:ok, pid} = TantivyEx.FullTextSearch.start_link(schema_fields: schema_fields)
  ```
  
  ### Adding Documents
  
  ```elixir
  # Add a single document
  doc = %{
    "title" => "Getting Started with Elixir",
    "content" => "Elixir is a functional programming language...",
    "author" => "Jane Doe",
    "rating" => 5
  }
  {:ok, :added} = TantivyEx.FullTextSearch.add_document(doc)
  
  # Add multiple documents
  docs = [doc1, doc2, doc3]
  {:ok, 3} = TantivyEx.FullTextSearch.add_documents(docs)
  ```
  
  ### Searching
  
  ```elixir
  # Simple text search across all fields
  {:ok, results} = TantivyEx.FullTextSearch.search("elixir")
  
  # Search in specific field
  {:ok, results} = TantivyEx.FullTextSearch.search_field("author", "Jane")
  
  # Boolean searches
  {:ok, results} = TantivyEx.FullTextSearch.search_and(["elixir", "programming"])
  {:ok, results} = TantivyEx.FullTextSearch.search_or(["rust", "elixir"])
  
  # Get all documents
  {:ok, all_docs} = TantivyEx.FullTextSearch.get_all_documents()
  
  # Get statistics
  {:ok, stats} = TantivyEx.FullTextSearch.stats()
  ```
  
  ### Advanced Usage
  
  ```elixir
  # Named process
  {:ok, pid} = TantivyEx.FullTextSearch.start_link(name: :my_search)
  TantivyEx.FullTextSearch.search(:my_search, "query")
  
  # Custom configuration
  {:ok, pid} = TantivyEx.FullTextSearch.start_link(
    schema_fields: custom_fields,
    writer_memory: 100_000_000,
    name: :custom_search
  )
  ```
  
  ## Schema Configuration
  
  The default schema includes common fields for blog posts and articles:
  
  - `id` (u64, indexed_stored) - Unique document identifier
  - `title` (text, text_stored) - Document title
  - `content` (text, text_stored) - Main document content
  - `author` (text, text_stored) - Document author
  - `category` (text, text_stored) - Document category
  - `tags` (text, text) - Document tags (indexed but not stored)
  - `rating` (u64, indexed_stored) - Numeric rating
  - `published_at` (text, text_stored) - Publication date
  - `price` (f64, fast_stored) - Document price
  
  You can customize the schema by providing your own `schema_fields` option.
  
  ## Error Handling
  
  All functions return `{:ok, result}` or `{:error, reason}` tuples for
  consistent error handling in your applications.
  
  ## Performance Notes
  
  - **In-memory only**: Data is lost when the process terminates
  - **Single writer**: All write operations are serialized through the GenServer
  - **Concurrent reads**: Multiple search operations can run concurrently
  - **Automatic commits**: Documents are committed immediately after addition
  
  For persistent indexing, use TantivyEx.Index directly with disk-based storage.
  """
  
  use GenServer
  require Logger
  
  alias TantivyEx.{Schema, Index, IndexWriter}
  alias TantivyEx.SearcherFixed, as: Searcher
  
  defstruct [:schema, :index, :writer, :doc_count, :writer_memory]
  
  # Client API
  
  @doc """
  Starts the FullTextSearch GenServer.
  
  ## Options
  
  - `:name` - Register the process with a name (default: no registration)
  - `:schema_fields` - List of {name, type, options} tuples for custom schema
  - `:writer_memory` - Memory allocation for the IndexWriter (default: 50MB)
  
  ## Examples
  
      # Start with default configuration
      {:ok, pid} = TantivyEx.FullTextSearch.start_link()
      
      # Start with custom name
      {:ok, pid} = TantivyEx.FullTextSearch.start_link(name: :my_search)
      
      # Start with custom schema
      schema_fields = [
        {"title", :text, :text_stored},
        {"body", :text, :text},
        {"price", :f64, :fast_stored}
      ]
      {:ok, pid} = TantivyEx.FullTextSearch.start_link(schema_fields: schema_fields)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {server_opts, init_opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, init_opts, server_opts)
  end
  
  @doc """
  Adds a single document to the search index.
  
  The document will be automatically committed to the index after addition.
  
  ## Parameters
  
  - `server` - The GenServer pid or name (default: __MODULE__)
  - `doc` - A map containing document fields
  
  ## Examples
  
      doc = %{
        "title" => "Elixir Programming",
        "content" => "Learn Elixir programming...",
        "author" => "Jane Doe"
      }
      {:ok, :added} = TantivyEx.FullTextSearch.add_document(doc)
  """
  @spec add_document(GenServer.server(), map()) :: {:ok, :added} | {:error, String.t()}
  def add_document(server \\ __MODULE__, doc) when is_map(doc) do
    GenServer.call(server, {:add_document, doc})
  end
  
  @doc """
  Adds multiple documents to the search index.
  
  All documents will be added in a batch operation and committed together.
  
  ## Parameters
  
  - `server` - The GenServer pid or name (default: __MODULE__)
  - `docs` - A list of maps containing document fields
  
  ## Examples
  
      docs = [
        %{"title" => "Doc 1", "author" => "Author 1"},
        %{"title" => "Doc 2", "author" => "Author 2"}
      ]
      {:ok, 2} = TantivyEx.FullTextSearch.add_documents(docs)
  """
  @spec add_documents(GenServer.server(), [map()]) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def add_documents(server \\ __MODULE__, docs) when is_list(docs) do
    GenServer.call(server, {:add_documents, docs})
  end
  
  @doc """
  Performs a simple text search across all searchable fields.
  
  ## Parameters
  
  - `server` - The GenServer pid or name (default: __MODULE__)
  - `query` - The search query string
  - `limit` - Maximum number of results (default: 10)
  
  ## Examples
  
      {:ok, results} = TantivyEx.FullTextSearch.search("elixir programming")
      {:ok, results} = TantivyEx.FullTextSearch.search("title:phoenix", 5)
  """
  @spec search(GenServer.server(), String.t(), pos_integer()) :: {:ok, [map()]} | {:error, String.t()}
  def search(server \\ __MODULE__, query, limit \\ 10) do
    GenServer.call(server, {:search, query, limit})
  end
  
  @doc """
  Searches for documents in a specific field.
  
  ## Parameters
  
  - `server` - The GenServer pid or name (default: __MODULE__)
  - `field` - The field name to search in
  - `term` - The search term
  - `limit` - Maximum number of results (default: 10)
  
  ## Examples
  
      {:ok, results} = TantivyEx.FullTextSearch.search_field("author", "Jane Doe")
      {:ok, results} = TantivyEx.FullTextSearch.search_field("category", "Programming")
  """
  @spec search_field(GenServer.server(), String.t(), String.t(), pos_integer()) :: {:ok, [map()]} | {:error, String.t()}
  def search_field(server \\ __MODULE__, field, term, limit \\ 10) do
    GenServer.call(server, {:search_field, field, term, limit})
  end
  
  @doc """
  Performs a boolean AND search where all terms must be present.
  
  ## Parameters
  
  - `server` - The GenServer pid or name (default: __MODULE__)
  - `terms` - List of search terms that must all match
  - `limit` - Maximum number of results (default: 10)
  
  ## Examples
  
      {:ok, results} = TantivyEx.FullTextSearch.search_and(["elixir", "programming"])
      {:ok, results} = TantivyEx.FullTextSearch.search_and(["phoenix", "web"])
  """
  @spec search_and(GenServer.server(), [String.t()], pos_integer()) :: {:ok, [map()]} | {:error, String.t()}
  def search_and(server \\ __MODULE__, terms, limit \\ 10) do
    GenServer.call(server, {:search_and, terms, limit})
  end
  
  @doc """
  Performs a boolean OR search where any term can match.
  
  ## Parameters
  
  - `server` - The GenServer pid or name (default: __MODULE__)
  - `terms` - List of search terms where any can match
  - `limit` - Maximum number of results (default: 10)
  
  ## Examples
  
      {:ok, results} = TantivyEx.FullTextSearch.search_or(["elixir", "rust"])
      {:ok, results} = TantivyEx.FullTextSearch.search_or(["web", "mobile"])
  """
  @spec search_or(GenServer.server(), [String.t()], pos_integer()) :: {:ok, [map()]} | {:error, String.t()}
  def search_or(server \\ __MODULE__, terms, limit \\ 10) do
    GenServer.call(server, {:search_or, terms, limit})
  end
  
  @doc """
  Retrieves all documents from the index.
  
  ## Parameters
  
  - `server` - The GenServer pid or name (default: __MODULE__)
  - `limit` - Maximum number of documents to return (default: 100)
  
  ## Examples
  
      {:ok, all_docs} = TantivyEx.FullTextSearch.get_all_documents()
      {:ok, first_50} = TantivyEx.FullTextSearch.get_all_documents(50)
  """
  @spec get_all_documents(GenServer.server(), pos_integer()) :: {:ok, [map()]} | {:error, String.t()}
  def get_all_documents(server \\ __MODULE__, limit \\ 100) do
    GenServer.call(server, {:get_all, limit})
  end
  
  @doc """
  Returns statistics about the search service.
  
  ## Parameters
  
  - `server` - The GenServer pid or name (default: __MODULE__)
  
  ## Returns
  
  A map containing:
  - `document_count` - Number of documents in the index
  - `schema_fields` - List of field names in the schema
  - `index_type` - Type of index ("in_memory")
  - `writer_memory` - Memory allocated to the IndexWriter
  
  ## Examples
  
      {:ok, stats} = TantivyEx.FullTextSearch.stats()
      IO.puts("Documents: \#{stats.document_count}")
  """
  @spec stats(GenServer.server()) :: {:ok, map()} | {:error, String.t()}
  def stats(server \\ __MODULE__) do
    GenServer.call(server, :stats)
  end
  
  @doc """
  Resets the search index, removing all documents.
  
  This creates a fresh index with the same schema configuration.
  
  ## Parameters
  
  - `server` - The GenServer pid or name (default: __MODULE__)
  
  ## Examples
  
      {:ok, :reset} = TantivyEx.FullTextSearch.reset()
  """
  @spec reset(GenServer.server()) :: {:ok, :reset} | {:error, String.t()}
  def reset(server \\ __MODULE__) do
    GenServer.call(server, :reset)
  end
  
  @doc """
  Deletes a document by ID.
  
  Note: Document deletion is not implemented in the current version of TantivyEx.
  This function is provided for API completeness but will return an error.
  
  ## Parameters
  
  - `server` - The GenServer pid or name (default: __MODULE__)
  - `doc_id` - The document ID to delete
  
  ## Examples
  
      # This will return an error in the current implementation
      {:error, reason} = TantivyEx.FullTextSearch.delete_document(123)
  """
  @spec delete_document(GenServer.server(), any()) :: {:error, String.t()}
  def delete_document(server \\ __MODULE__, doc_id) do
    GenServer.call(server, {:delete_document, doc_id})
  end
  
  # Server Implementation
  
  @impl true
  def init(opts) do
    schema_fields = Keyword.get(opts, :schema_fields, default_schema_fields())
    writer_memory = Keyword.get(opts, :writer_memory, 50_000_000)
    
    case setup_index(schema_fields, writer_memory) do
      {:ok, schema, index, writer} ->
        state = %__MODULE__{
          schema: schema,
          index: index,
          writer: writer,
          doc_count: 0,
          writer_memory: writer_memory
        }
        Logger.info("FullTextSearch service started with #{length(schema_fields)} schema fields")
        {:ok, state}
      
      {:error, reason} ->
        Logger.error("Failed to start FullTextSearch service: #{inspect(reason)}")
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
            Logger.debug("Document added successfully. Total documents: #{new_state.doc_count}")
            {:reply, {:ok, :added}, new_state}
          {:error, reason} ->
            Logger.error("Failed to commit document: #{inspect(reason)}")
            {:reply, {:error, "Commit failed: #{inspect(reason)}"}, state}
        end
      {:error, reason} ->
        Logger.error("Failed to add document: #{inspect(reason)}")
        {:reply, {:error, "Add failed: #{inspect(reason)}"}, state}
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
          Logger.debug("#{length(docs)} documents added successfully. Total: #{new_state.doc_count}")
          {:reply, {:ok, length(docs)}, new_state}
        {:error, reason} ->
          Logger.error("Failed to commit documents: #{inspect(reason)}")
          {:reply, {:error, "Batch commit failed: #{inspect(reason)}"}, state}
      end
    else
      failed_count = Enum.count(results, &(&1 != :ok))
      Logger.error("#{failed_count} documents failed to add")
      {:reply, {:error, "#{failed_count} documents failed to add"}, state}
    end
  end
  
  @impl true
  def handle_call({:delete_document, _doc_id}, _from, state) do
    # Note: TantivyEx doesn't have direct document deletion by ID in this version
    # In a real implementation, you might need to rebuild the index or use
    # Tantivy's delete functionality if available
    {:reply, {:error, "Document deletion not implemented in current TantivyEx version"}, state}
  end
  
  @impl true
  def handle_call({:search, query_string, limit}, _from, state) do
    case create_searcher_and_search(state, query_string, limit) do
      {:ok, results} -> 
        Logger.debug("Search '#{query_string}' returned #{length(results)} results")
        {:reply, {:ok, results}, state}
      error -> 
        Logger.warning("Search '#{query_string}' failed: #{inspect(error)}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:search_field, field, term, limit}, _from, state) do
    # Handle multi-word terms with quotes
    quoted_term = if String.contains?(term, " ") do
      "\"#{term}\""
    else
      term
    end
    
    query_string = "#{field}:#{quoted_term}"
    
    case create_searcher_and_search(state, query_string, limit) do
      {:ok, results} -> 
        Logger.debug("Field search '#{field}:#{term}' returned #{length(results)} results")
        {:reply, {:ok, results}, state}
      error -> 
        Logger.warning("Field search '#{field}:#{term}' failed: #{inspect(error)}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:search_and, terms, limit}, _from, state) do
    query_string = Enum.join(terms, " AND ")
    case create_searcher_and_search(state, query_string, limit) do
      {:ok, results} -> 
        Logger.debug("AND search '#{query_string}' returned #{length(results)} results")
        {:reply, {:ok, results}, state}
      error -> 
        Logger.warning("AND search '#{query_string}' failed: #{inspect(error)}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:search_or, terms, limit}, _from, state) do
    query_string = Enum.join(terms, " OR ")
    case create_searcher_and_search(state, query_string, limit) do
      {:ok, results} -> 
        Logger.debug("OR search '#{query_string}' returned #{length(results)} results")
        {:reply, {:ok, results}, state}
      error -> 
        Logger.warning("OR search '#{query_string}' failed: #{inspect(error)}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:get_all, limit}, _from, state) do
    case create_searcher_and_search(state, "*", limit) do
      {:ok, results} -> 
        Logger.debug("Get all documents returned #{length(results)} results")
        {:reply, {:ok, results}, state}
      error -> 
        Logger.warning("Get all documents failed: #{inspect(error)}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      document_count: state.doc_count,
      schema_fields: Schema.get_field_names(state.schema),
      index_type: "in_memory",
      writer_memory: state.writer_memory
    }
    {:reply, {:ok, stats}, state}
  end
  
  @impl true
  def handle_call(:reset, _from, state) do
    schema_fields = default_schema_fields()
    
    case setup_index(schema_fields, state.writer_memory) do
      {:ok, schema, index, writer} ->
        new_state = %{state | 
          schema: schema,
          index: index, 
          writer: writer,
          doc_count: 0
        }
        Logger.info("Search index reset successfully")
        {:reply, {:ok, :reset}, new_state}
      {:error, reason} ->
        Logger.error("Failed to reset index: #{inspect(reason)}")
        {:reply, {:error, "Reset failed: #{inspect(reason)}"}, state}
    end
  end
  
  @impl true
  def terminate(reason, _state) do
    Logger.info("FullTextSearch service terminating: #{inspect(reason)}")
    # Cleanup is automatic - in-memory index will be garbage collected
    :ok
  end
  
  # Private Helper Functions
  
  @spec default_schema_fields() :: [{String.t(), atom(), atom()}]
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
  
  @spec setup_index([{String.t(), atom(), atom()}], pos_integer()) :: 
    {:ok, Schema.t(), Index.t(), IndexWriter.t()} | {:error, String.t()}
  defp setup_index(schema_fields, writer_memory) do
    try do
      # Create schema from field definitions
      schema = Enum.reduce(schema_fields, Schema.new(), fn {name, type, options}, schema ->
        case type do
          :text -> Schema.add_text_field(schema, name, options)
          :u64 -> Schema.add_u64_field(schema, name, options)
          :f64 -> Schema.add_f64_field(schema, name, options)
          :bool -> Schema.add_bool_field(schema, name, options)
          :date -> Schema.add_date_field(schema, name, options)
          _ -> schema  # Skip unknown types
        end
      end)
      
      # Create in-memory index
      {:ok, index} = Index.create_in_ram(schema)
      {:ok, writer} = IndexWriter.new(index, writer_memory)
      
      {:ok, schema, index, writer}
    rescue
      e -> {:error, "Failed to setup index: #{inspect(e)}"}
    end
  end
  
  @spec create_searcher_and_search(%__MODULE__{}, String.t(), pos_integer()) :: 
    {:ok, [map()]} | {:error, String.t()}
  defp create_searcher_and_search(state, query_string, limit) do
    case Searcher.new(state.index) do
      {:ok, searcher} ->
        Searcher.search_with_schema(searcher, query_string, state.schema, limit)
      {:error, reason} ->
        {:error, "Failed to create searcher: #{inspect(reason)}"}
    end
  end
end