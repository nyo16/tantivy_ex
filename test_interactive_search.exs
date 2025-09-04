# Test Interactive Search Helpers
# Run with: elixir -S mix run test_interactive_search.exs

# Load the SearchService and start it
Code.compile_file("search_service_demo.exs")

IO.puts("🧪 Testing Interactive Search Helpers")
IO.puts(String.duplicate("=", 45))

# Wait a moment for the service to be ready
Process.sleep(100)

# Test the quick search helper
IO.puts("\n1. Testing SearchHelpers.q(\"functional\"):")
case SearchHelpers.q("functional") do
  {:ok, results} ->
    IO.puts("✅ Found #{length(results)} result(s)")
    Enum.each(results, fn result ->
      title = Map.get(result, "title", "No title")
      IO.puts("   📖 #{title}")
    end)
  {:error, error} ->
    IO.puts("❌ Error: #{error}")
end

# Test author search
IO.puts("\n2. Testing SearchHelpers.author(\"Carol\"):")
case SearchHelpers.author("Carol") do
  {:ok, results} ->
    IO.puts("✅ Found #{length(results)} result(s)")
    Enum.each(results, fn result ->
      title = Map.get(result, "title", "No title")
      author = Map.get(result, "author", "Unknown")
      IO.puts("   👤 #{title} by #{author}")
    end)
  {:error, error} ->
    IO.puts("❌ Error: #{error}")
end

# Test category search
IO.puts("\n3. Testing SearchHelpers.category(\"Web\"):")
case SearchHelpers.category("Web") do
  {:ok, results} ->
    IO.puts("✅ Found #{length(results)} result(s)")
    Enum.each(results, fn result ->
      title = Map.get(result, "title", "No title")
      category = Map.get(result, "category", "Uncategorized")
      IO.puts("   📂 #{title} in #{category}")
    end)
  {:error, error} ->
    IO.puts("❌ Error: #{error}")
end

# Test stats
IO.puts("\n4. Testing SearchHelpers.stats():")
case SearchHelpers.stats() do
  {:ok, stats} ->
    IO.puts("✅ Statistics:")
    IO.puts("   📄 Documents: #{stats.document_count}")
    IO.puts("   🏷️  Fields: #{length(stats.schema_fields)}")
    IO.puts("   💾 Type: #{stats.index_type}")
  {:error, error} ->
    IO.puts("❌ Error: #{error}")
end

# Test getting all documents  
IO.puts("\n5. Testing SearchHelpers.all():")
case SearchHelpers.all() do
  {:ok, results} ->
    IO.puts("✅ Retrieved all #{length(results)} document(s):")
    Enum.with_index(results, 1) |> Enum.each(fn {result, idx} ->
      title = Map.get(result, "title", "No title")
      rating = Map.get(result, "rating", 0)
      IO.puts("   #{idx}. #{title} (⭐ #{rating})")
    end)
  {:error, error} ->
    IO.puts("❌ Error: #{error}")
end

# Test adding a new document dynamically
IO.puts("\n6. Testing dynamic document addition:")
new_doc = %{
  "id" => 6,
  "title" => "Advanced GenServer Patterns",
  "content" => "Learn advanced GenServer patterns for building robust Elixir applications with proper state management and error handling.",
  "author" => "Dave Thomas",
  "category" => "Advanced Programming",
  "tags" => "elixir genserver otp patterns",
  "rating" => 5,
  "published_at" => "2024-03-15",
  "price" => 54.99
}

case SearchService.add_document(new_doc) do
  {:ok, :added} ->
    IO.puts("✅ Successfully added new document")
    
    # Search for the new document
    case SearchHelpers.q("GenServer") do
      {:ok, results} ->
        IO.puts("✅ Found #{length(results)} result(s) for 'GenServer':")
        Enum.each(results, fn result ->
          title = Map.get(result, "title", "No title")
          IO.puts("   📚 #{title}")
        end)
      {:error, error} ->
        IO.puts("❌ Search error: #{error}")
    end
    
  {:error, error} ->
    IO.puts("❌ Failed to add document: #{error}")
end

IO.puts("\n🎉 Interactive testing complete!")
IO.puts("\n💡 You can continue using these helpers:")
IO.puts("   SearchHelpers.q(\"your search term\")")
IO.puts("   SearchHelpers.author(\"author name\")")
IO.puts("   SearchHelpers.category(\"category\")")
IO.puts("   SearchService.search_and([\"term1\", \"term2\"])")
IO.puts("   SearchService.search_or([\"term1\", \"term2\"])")