# Advanced Query Examples - Full Tantivy API Flexibility in Elixir
# Run with: elixir -S mix run example_advanced_queries.exs

alias TantivyEx.{Schema, Index, IndexWriter, Searcher, Query}

IO.puts("🚀 Advanced Query Examples - Full Tantivy Flexibility")
IO.puts(String.duplicate("=", 60))

# Create schema with :fast_stored fields for full functionality
schema = Schema.new()
         |> Schema.add_text_field("title", :fast_stored)
         |> Schema.add_text_field("body", :fast_stored)
         |> Schema.add_text_field("author", :fast_stored)

{:ok, index} = Index.create_in_ram(schema)
{:ok, writer} = IndexWriter.new(index, 50_000_000)

# Add test documents
docs = [
  %{
    "title" => "Getting Started with Rust",
    "body" => "Rust is a systems programming language focused on safety",
    "author" => "Alex Johnson"
  },
  %{
    "title" => "Getting Started with Elixir", 
    "body" => "Elixir is a functional programming language with great concurrency",
    "author" => "Jane Smith"
  },
  %{
    "title" => "Advanced Rust Techniques",
    "body" => "Advanced techniques for Rust development and safety patterns", 
    "author" => "Bob Wilson"
  },
  %{
    "title" => "The Success of Modern Languages",
    "body" => "Success stories of modern programming languages in the industry",
    "author" => "Carol Davis" 
  }
]

Enum.each(docs, &IndexWriter.add_document(writer, &1))
IndexWriter.commit(writer)
{:ok, searcher} = Searcher.new(index)

IO.puts("✅ Setup: #{length(docs)} documents with :fast_stored fields")

# Example 1: Native QueryParser (like Rust QueryParser::for_index)
IO.puts("\n📋 1. Native QueryParser - Like Rust QueryParser::for_index(&index, vec![title, body])")
{:ok, parser} = Query.parser(index, ["title", "body"])

queries = [
  "rust",
  "title:rust", 
  "rust AND programming",
  "title:getting^10 body:programming^5",  # Boost scoring
  "(rust OR elixir) AND programming"
]

Enum.each(queries, fn query_str ->
  case Query.parse(parser, query_str) do
    {:ok, query} ->
      case Searcher.search(searcher, query, 10) do
        {:ok, results} ->
          IO.puts("   '#{query_str}' → #{length(results)} result(s)")
        {:error, err} ->
          IO.puts("   '#{query_str}' → ERROR: #{err}")
      end
    {:error, err} ->
      IO.puts("   '#{query_str}' → PARSE ERROR: #{err}")
  end
end)

# Example 2: Phrase Prefix Queries (like Rust example)
IO.puts("\n📋 2. Phrase Prefix Queries - Like Rust \"in the su\"*")

phrase_prefix_examples = [
  {"getting star", "Find 'getting started with'"},
  {"rust progr", "Find 'rust programming'"},
  {"modern lang", "Find 'modern languages'"}
]

Enum.each(phrase_prefix_examples, fn {prefix_query, description} ->
  IO.puts("\n   #{description}")
  
  # Method 1: Using phrase_with_prefix directly
  case String.split(prefix_query, " ") do
    [_single_term] ->
      IO.puts("   Skipping single term for phrase prefix")
    terms when length(terms) > 1 ->
      {phrase_terms, [prefix_term]} = Enum.split(terms, -1)
      case Query.phrase_with_prefix(schema, "body", phrase_terms, prefix_term) do
        {:ok, query} ->
          case Searcher.search(searcher, query, 10) do
            {:ok, results} ->
              IO.puts("   Direct: '#{prefix_query}' → #{length(results)} result(s)")
            {:error, err} ->
              IO.puts("   Direct: ERROR - #{err}")
          end
        {:error, err} ->
          IO.puts("   Direct: ERROR - #{err}")
      end
  end
  
  # Method 2: Using parse helper (like Rust query_parser.parse_query("\"...\"*"))  
  query_string = "\"#{prefix_query}\"*"
  case Query.parse_phrase_prefix(schema, "body", query_string) do
    {:ok, query} ->
      case Searcher.search(searcher, query, 10) do
        {:ok, results} ->
          IO.puts("   Parsed: '#{query_string}' → #{length(results)} result(s)")
        {:error, err} ->
          IO.puts("   Parsed: ERROR - #{err}")
      end
    {:error, err} ->
      IO.puts("   Parsed: ERROR - #{err}")
  end
end)

# Example 3: Comprehensive Query Types
IO.puts("\n📋 3. All Query Types Available")

query_examples = [
  {"Term Query", fn -> Query.term(schema, "author", "Jane Smith") end},
  {"Phrase Query", fn -> Query.phrase(schema, "title", ["Getting", "Started"]) end},
  {"Boolean AND", fn -> 
    with {:ok, q1} <- Query.term(schema, "title", "rust"),
         {:ok, q2} <- Query.term(schema, "body", "programming") do
      Query.boolean([q1, q2], [], [])
    end
  end},
  {"Boolean OR", fn ->
    with {:ok, q1} <- Query.term(schema, "title", "rust"),
         {:ok, q2} <- Query.term(schema, "title", "elixir") do
      Query.boolean([], [q1, q2], [])
    end
  end},
  {"Regex Query", fn -> Query.regex(schema, "title", ".*Rust.*") end},
  {"Wildcard Query", fn -> Query.wildcard(schema, "title", "*Started*") end},
  {"All Query", fn -> Query.all() end}
]

Enum.each(query_examples, fn {name, query_fn} ->
  case query_fn.() do
    {:ok, query} ->
      case Searcher.search(searcher, query, 10) do
        {:ok, results} ->
          IO.puts("   #{name}: #{length(results)} result(s)")
        {:error, err} ->
          IO.puts("   #{name}: SEARCH ERROR - #{err}")
      end
    {:error, err} ->
      IO.puts("   #{name}: QUERY ERROR - #{err}")
  end
end)

# Example 4: Complex Composed Queries
IO.puts("\n📋 4. Complex Composed Queries - Full Flexibility")

# Build a complex query step by step (like in Rust)
with {:ok, rust_term} <- Query.term(schema, "title", "rust"),
     {:ok, elixir_term} <- Query.term(schema, "title", "elixir"),
     {:ok, programming_phrase} <- Query.phrase(schema, "body", ["programming", "language"]),
     {:ok, language_or} <- Query.boolean([], [rust_term, elixir_term], []),  # rust OR elixir
     {:ok, final_query} <- Query.boolean([language_or, programming_phrase], [], []) do  # (rust OR elixir) AND "programming language"
  
  case Searcher.search(searcher, final_query, 10) do
    {:ok, results} ->
      IO.puts("   Complex Query: (rust OR elixir) AND \"programming language\" → #{length(results)} result(s)")
      Enum.with_index(results, 1) |> Enum.each(fn {result, idx} ->
        title = Map.get(result, "title", "No title")
        IO.puts("      #{idx}. #{title}")
      end)
    {:error, err} ->
      IO.puts("   Complex Query ERROR: #{err}")
  end
else
  {:error, err} -> IO.puts("   Complex Query BUILD ERROR: #{err}")
end

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("🎯 SUMMARY:")
IO.puts("✅ Native QueryParser with boost scoring")
IO.puts("✅ Phrase prefix queries (\"in the su\"* equivalent)")  
IO.puts("✅ All Tantivy query types exposed")
IO.puts("✅ Full composability for complex queries")
IO.puts("✅ Same flexibility as Rust API!")