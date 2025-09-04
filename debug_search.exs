# Debug search functionality to identify the exact issue

alias TantivyEx.{Schema, Index, IndexWriter, Searcher}

IO.puts("=== DEBUG SEARCH TEST ===")

# Step 1: Create Schema
schema = Schema.new()
         |> Schema.add_text_field("title", :text_stored)
         |> Schema.add_text_field("content", :text)

# Step 2: Create Index
{:ok, index} = Index.create_in_ram(schema)
{:ok, writer} = IndexWriter.new(index, 50_000_000)

# Step 3: Add DISTINCT documents with UNIQUE KEYWORDS
documents = [
  %{
    "title" => "Document One About Dogs",
    "content" => "This document is specifically about dogs and canines."
  },
  %{
    "title" => "Document Two About Cats",
    "content" => "This document is specifically about cats and felines."
  },
  %{
    "title" => "Document Three About Birds",
    "content" => "This document is specifically about birds and flying."
  }
]

Enum.each(documents, fn doc ->
  :ok = IndexWriter.add_document(writer, doc)
end)

:ok = IndexWriter.commit(writer)

# Step 4: Create searcher
{:ok, searcher} = Searcher.new(index)

# Step 5: Test targeted searches
test_queries = [
  {"dogs", "Should only return Document One"},
  {"cats", "Should only return Document Two"}, 
  {"birds", "Should only return Document Three"},
  {"canines", "Should only return Document One"},
  {"felines", "Should only return Document Two"},
  {"flying", "Should only return Document Three"},
  {"title:Dogs", "Field-specific search for Dogs in title"},
  {"title:Cats", "Field-specific search for Cats in title"},
  {"nonexistent", "Should return no results"}
]

IO.puts("\n--- TESTING DISTINCT SEARCHES ---")
Enum.each(test_queries, fn {query, description} ->
  IO.puts("\nQuery: '#{query}' - #{description}")
  
  case Searcher.search(searcher, query, 10) do
    {:ok, results} ->
      IO.puts("Results: #{length(results)} documents found")
      if length(results) > 0 do
        Enum.with_index(results, 1) |> Enum.each(fn {result, idx} ->
          title = Map.get(result, "title", "No title")
          content = Map.get(result, "content", "No content")
          IO.puts("  #{idx}. #{title}")
          IO.puts("     Content: #{String.slice(content, 0, 50)}...")
        end)
      else
        IO.puts("  No results found - this is expected for 'nonexistent' query")
      end
    {:error, error} ->
      IO.puts("ERROR: #{inspect(error)}")
  end
end)

# Step 6: Check if the issue is with document retrieval
IO.puts("\n--- CHECKING ALL DOCUMENTS ---")
case Searcher.search(searcher, "*", 10) do
  {:ok, all_results} ->
    IO.puts("Total documents indexed: #{length(all_results)}")
    Enum.with_index(all_results, 1) |> Enum.each(fn {result, idx} ->
      title = Map.get(result, "title", "No title")
      content = Map.get(result, "content", "No content") |> String.slice(0, 50)
      IO.puts("  #{idx}. #{title} - #{content}...")
    end)
  {:error, error} ->
    IO.puts("ERROR getting all documents: #{inspect(error)}")
end

IO.puts("\n=== DEBUG COMPLETE ===")