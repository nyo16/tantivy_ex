# Test the proper Query API instead of string-based search

alias TantivyEx.{Schema, Index, IndexWriter, Searcher, Query}

IO.puts("=== TESTING QUERY API ===")

# Step 1: Create Schema
schema = Schema.new()
         |> Schema.add_text_field("title", :text_stored)
         |> Schema.add_text_field("content", :text_stored)

# Step 2: Create Index
{:ok, index} = Index.create_in_ram(schema)
{:ok, writer} = IndexWriter.new(index, 50_000_000)

# Step 3: Add distinct documents
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

# Step 5: Test using Query API instead of strings
IO.puts("\n--- TESTING WITH QUERY API ---")

# Test 1: Term query for "dogs"
IO.puts("\n1. Term query for 'dogs' in title field:")
case Query.term(schema, "title", "dogs") do
  {:ok, query} ->
    case Searcher.search(searcher, query, 10) do
      {:ok, results} ->
        IO.puts("Found #{length(results)} results")
        Enum.with_index(results, 1) |> Enum.each(fn {result, idx} ->
          title = Map.get(result, "title", "No title")
          content = Map.get(result, "content", "No content")
          IO.puts("  #{idx}. #{title}")
          IO.puts("     Content: #{content}")
        end)
      {:error, error} ->
        IO.puts("Search error: #{inspect(error)}")
    end
  {:error, error} ->
    IO.puts("Query creation error: #{inspect(error)}")
end

# Test 2: Term query for "cats"
IO.puts("\n2. Term query for 'cats' in title field:")
case Query.term(schema, "title", "cats") do
  {:ok, query} ->
    case Searcher.search(searcher, query, 10) do
      {:ok, results} ->
        IO.puts("Found #{length(results)} results")
        Enum.with_index(results, 1) |> Enum.each(fn {result, idx} ->
          title = Map.get(result, "title", "No title")
          content = Map.get(result, "content", "No content")  
          IO.puts("  #{idx}. #{title}")
          IO.puts("     Content: #{content}")
        end)
      {:error, error} ->
        IO.puts("Search error: #{inspect(error)}")
    end
  {:error, error} ->
    IO.puts("Query creation error: #{inspect(error)}")
end

# Test 3: Try with search_with_parser for Lucene-style queries
IO.puts("\n3. Using search_with_parser for 'title:dogs':")
case Searcher.search_with_parser(searcher, schema, ["title", "content"], "title:dogs", 10) do
  {:ok, results} ->
    IO.puts("Found #{length(results)} results")
    Enum.with_index(results, 1) |> Enum.each(fn {result, idx} ->
      title = Map.get(result, "title", "No title")
      content = Map.get(result, "content", "No content")
      IO.puts("  #{idx}. #{title}")  
      IO.puts("     Content: #{content}")
    end)
  {:error, error} ->
    IO.puts("Parser search error: #{inspect(error)}")
end

# Test 4: All documents query to verify indexing
IO.puts("\n4. All documents query:")
case Query.all() do
  {:ok, query} ->
    case Searcher.search(searcher, query, 10) do
      {:ok, results} ->
        IO.puts("Total indexed documents: #{length(results)}")
        Enum.with_index(results, 1) |> Enum.each(fn {result, idx} ->
          title = Map.get(result, "title", "No title")
          content = Map.get(result, "content", "No content")
          IO.puts("  #{idx}. #{title}")
          IO.puts("     Content: #{content}")
        end)
      {:error, error} ->
        IO.puts("All query search error: #{inspect(error)}")
    end
  {:error, error} ->
    IO.puts("All query creation error: #{inspect(error)}")
end

IO.puts("\n=== QUERY API TEST COMPLETE ===")