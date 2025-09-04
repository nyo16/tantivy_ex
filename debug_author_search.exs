# Debug the author search issue

alias TantivyEx.{Schema, Index, IndexWriter, Query}
alias TantivyEx.SearcherFixed, as: Searcher

IO.puts("=== DEBUGGING AUTHOR SEARCH ===")

# Create same schema and data as the test
schema = Schema.new()
         |> Schema.add_text_field("title", :text_stored)
         |> Schema.add_text_field("content", :text_stored)
         |> Schema.add_text_field("author", :text_stored)
         |> Schema.add_text_field("tags", :text)
         |> Schema.add_u64_field("rating", :indexed_stored)
         |> Schema.add_text_field("category", :text_stored)

{:ok, index} = Index.create_in_ram(schema)
{:ok, writer} = IndexWriter.new(index, 50_000_000)

# Add just one document for testing
doc = %{
  "title" => "Getting Started with Elixir",
  "content" => "Elixir is a dynamic, functional language designed for building maintainable applications.",
  "author" => "Jane Doe",
  "tags" => "elixir programming functional", 
  "rating" => 5,
  "category" => "Programming"
}

:ok = IndexWriter.add_document(writer, doc)
:ok = IndexWriter.commit(writer)

{:ok, searcher} = Searcher.new(index)

IO.puts("Document added with author: 'Jane Doe'")

# Test 1: Check what fields exist in the schema
IO.puts("\nSchema fields:")
Schema.get_field_names(schema) |> Enum.each(fn name ->
  {:ok, type} = Schema.get_field_type(schema, name)
  IO.puts("  #{name}: #{type}")
end)

# Test 2: Get all documents to see what's actually stored
IO.puts("\nAll documents in index:")
{:ok, all_docs} = Searcher.search_with_schema(searcher, "*", schema, 10)
Enum.with_index(all_docs, 1) |> Enum.each(fn {doc, idx} ->
  author = Map.get(doc, "author", "NO_AUTHOR")
  title = Map.get(doc, "title", "NO_TITLE")  
  IO.puts("  #{idx}. Title: '#{title}', Author: '#{author}'")
end)

# Test 3: Try different author search variations
search_variations = [
  "author:\"Jane Doe\"",
  "author:Jane",  
  "author:Doe",
  "author:jane",
  "author:JANE",
  "Jane Doe",  # Search across all fields
  "Jane"       # Search across all fields
]

IO.puts("\nTesting author search variations:")
Enum.each(search_variations, fn query ->
  IO.puts("\nQuery: '#{query}'")
  case Searcher.search_with_schema(searcher, query, schema, 10) do
    {:ok, results} ->
      IO.puts("Results: #{length(results)}")
      Enum.with_index(results, 1) |> Enum.each(fn {result, idx} ->
        author = Map.get(result, "author", "NO_AUTHOR")
        title = Map.get(result, "title", "NO_TITLE")
        IO.puts("  #{idx}. #{title} by #{author}")
      end)
    {:error, error} ->
      IO.puts("ERROR: #{error}")
  end
end)

# Test 4: Try using Query API directly
IO.puts("\nTesting with Query API directly:")
case Query.term(schema, "author", "Jane Doe") do
  {:ok, query} ->
    case Searcher.search(searcher, query, 10, true, []) do
      {:ok, results} ->
        IO.puts("Direct Query API: Found #{length(results)} results")
        Enum.each(results, fn result ->
          author = Map.get(result, "author", "NO_AUTHOR")
          title = Map.get(result, "title", "NO_TITLE")
          IO.puts("  #{title} by #{author}")
        end)
      {:error, error} ->
        IO.puts("Direct Query API error: #{error}")
    end
  {:error, error} ->
    IO.puts("Query creation error: #{error}")
end

IO.puts("\n=== DEBUG COMPLETE ===")