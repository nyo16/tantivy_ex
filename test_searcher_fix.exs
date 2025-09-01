# Test the fixed SearcherFixed module

alias TantivyEx.{Schema, Index, IndexWriter}
alias TantivyEx.SearcherFixed, as: Searcher

IO.puts("=== TESTING SEARCHER FIX ===")

# Step 1: Create Schema
schema = Schema.new()
         |> Schema.add_text_field("title", :text_stored)
         |> Schema.add_text_field("content", :text_stored)
         |> Schema.add_text_field("author", :text_stored)
         |> Schema.add_text_field("tags", :text)
         |> Schema.add_u64_field("rating", :indexed_stored)
         |> Schema.add_text_field("category", :text_stored)

IO.puts("✓ Schema created")

# Step 2: Create Index
{:ok, index} = Index.create_in_ram(schema)
{:ok, writer} = IndexWriter.new(index, 50_000_000)

# Step 3: Add test documents with DISTINCT keywords
documents = [
  %{
    "title" => "Getting Started with Elixir",
    "content" => "Elixir is a dynamic, functional language designed for building maintainable applications.",
    "author" => "Jane Doe",
    "tags" => "elixir programming functional",
    "rating" => 5,
    "category" => "Programming"
  },
  %{
    "title" => "Introduction to Phoenix Framework", 
    "content" => "Phoenix is a web development framework written in Elixir for building web applications.",
    "author" => "John Smith",
    "tags" => "phoenix elixir web framework",
    "rating" => 4,
    "category" => "Web Development"
  },
  %{
    "title" => "Building Real-time Applications",
    "content" => "Phoenix provides built-in support for real-time features through Phoenix Channels.",
    "author" => "Alice Johnson", 
    "tags" => "phoenix realtime websockets",
    "rating" => 5,
    "category" => "Real-time"
  },
  %{
    "title" => "Rust Performance Guide",
    "content" => "Rust is a systems programming language that runs blazingly fast and prevents segfaults.",
    "author" => "Bob Wilson",
    "tags" => "rust performance systems",
    "rating" => 4,
    "category" => "Systems Programming"
  },
  %{
    "title" => "Functional Programming in Elixir",
    "content" => "Elixir embraces functional programming paradigms with immutability and pattern matching.",
    "author" => "Carol Brown",
    "tags" => "elixir functional immutability",
    "rating" => 5,
    "category" => "Programming"
  }
]

Enum.each(documents, fn doc ->
  :ok = IndexWriter.add_document(writer, doc)
end)
:ok = IndexWriter.commit(writer)

# Step 4: Create searcher
{:ok, searcher} = Searcher.new(index)

IO.puts("✓ Index created with #{length(documents)} documents")

# Step 5: Test various query patterns
test_cases = [
  # Basic term searches
  {"elixir", "Should find 3 Elixir-related documents", 3},
  {"rust", "Should find 1 Rust document", 1},
  {"phoenix", "Should find 2 Phoenix documents", 2},
  {"nonexistent", "Should find 0 documents", 0},
  
  # Field-specific searches  
  {"title:elixir", "Should find documents with 'elixir' in title", 2},
  {"author:\"Jane Doe\"", "Should find documents by Jane Doe", 1},
  {"category:Programming", "Should find Programming category docs", 3},
  {"rating:5", "Should find 5-star documents", 3},
  
  # Boolean queries
  {"elixir AND functional", "Should find docs with both terms", 2},
  {"elixir OR rust", "Should find docs with either term", 4}, 
  {"phoenix AND realtime", "Should find Phoenix real-time docs", 1},
  
  # Wildcard
  {"*", "Should return all documents", 5}
]

IO.puts("\n--- TESTING STRING SEARCH PATTERNS ---")

all_passed = Enum.all?(test_cases, fn {query, description, expected_count} ->
  IO.puts("\nTesting: #{query}")
  IO.puts("Description: #{description}")
  IO.puts("Expected: #{expected_count} result(s)")
  
  case Searcher.search_with_schema(searcher, query, schema, 10) do
    {:ok, results} ->
      actual_count = length(results)
      IO.puts("Actual: #{actual_count} result(s)")
      
      if actual_count == expected_count do
        IO.puts("✅ PASS")
        
        # Show results for verification
        if actual_count > 0 and actual_count <= 3 do
          Enum.with_index(results, 1) |> Enum.each(fn {result, idx} ->
            title = Map.get(result, "title", "No title")
            author = Map.get(result, "author", "Unknown")
            IO.puts("   #{idx}. #{title} by #{author}")
          end)
        end
        
        true
      else
        IO.puts("❌ FAIL - Expected #{expected_count}, got #{actual_count}")
        false
      end
      
    {:error, error} ->
      IO.puts("❌ ERROR: #{error}")
      false
  end
end)

# Step 6: Test advanced features
IO.puts("\n--- TESTING ADVANCED FEATURES ---")

IO.puts("\nTesting search_ids:")
case Searcher.search_ids(searcher, "elixir", 10, schema: schema) do
  {:ok, doc_ids} ->
    IO.puts("✅ search_ids works: #{inspect(doc_ids)}")
  {:error, error} ->
    IO.puts("❌ search_ids failed: #{error}")
end

IO.puts("\nTesting search_documents:")
case Searcher.search_documents(searcher, "phoenix", 10, schema: schema) do
  {:ok, results} ->
    IO.puts("✅ search_documents works: #{length(results)} documents with full content")
    # Verify content is included
    first_result = List.first(results)
    if first_result && Map.has_key?(first_result, "content") do
      IO.puts("✅ Document content is properly retrieved")
    else
      IO.puts("❌ Document content missing")
    end
  {:error, error} ->
    IO.puts("❌ search_documents failed: #{error}")
end

# Step 7: Compare with broken original
IO.puts("\n--- COMPARING WITH BROKEN ORIGINAL ---")
IO.puts("Testing original broken search for comparison:")

case TantivyEx.Searcher.search(searcher, "elixir", 10) do
  {:ok, results} ->
    IO.puts("Original search returned #{length(results)} results (should be 5 - all docs)")
    if length(results) == 5 do
      IO.puts("✅ Confirmed: Original search is broken (returns all docs)")
    end
  {:error, error} ->
    IO.puts("Original search error: #{error}")
end

# Final result
IO.puts("\n" <> String.duplicate("=", 60))
if all_passed do
  IO.puts("🎉 ALL TESTS PASSED! String search is now working correctly!")
  IO.puts("The SearcherFixed module successfully fixes the broken string search.")
else
  IO.puts("❌ Some tests failed. The fix needs more work.")
end
IO.puts(String.duplicate("=", 60))