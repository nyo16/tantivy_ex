# Debug phrase query directly

alias TantivyEx.{Schema, Index, IndexWriter, Query}
alias TantivyEx.SearcherFixed, as: Searcher

IO.puts("=== DEBUGGING PHRASE QUERY ===")

# Create schema and index
schema = Schema.new()
         |> Schema.add_text_field("author", :text_stored)

{:ok, index} = Index.create_in_ram(schema)
{:ok, writer} = IndexWriter.new(index, 50_000_000)

# Add document
doc = %{"author" => "Jane Doe"}
:ok = IndexWriter.add_document(writer, doc)
:ok = IndexWriter.commit(writer)

{:ok, searcher} = Searcher.new(index)

IO.puts("Document added with author: 'Jane Doe'")

# Test different query approaches
IO.puts("\n--- Testing Query API directly ---")

# Test 1: Term query for "Jane Doe" (should fail)
IO.puts("\n1. Term query for 'Jane Doe':")
case Query.term(schema, "author", "Jane Doe") do
  {:ok, query} ->
    case Searcher.search(searcher, query, 10) do
      {:ok, results} ->
        IO.puts("   Results: #{length(results)}")
      {:error, error} ->
        IO.puts("   Error: #{error}")
    end
  {:error, error} ->
    IO.puts("   Query creation error: #{error}")
end

# Test 2: Phrase query for ["Jane", "Doe"] (should work)
IO.puts("\n2. Phrase query for ['Jane', 'Doe']:")
case Query.phrase(schema, "author", ["Jane", "Doe"]) do
  {:ok, query} ->
    case Searcher.search(searcher, query, 10) do
      {:ok, results} ->
        IO.puts("   Results: #{length(results)}")
        Enum.each(results, fn result ->
          author = Map.get(result, "author", "NO_AUTHOR")
          IO.puts("   Found: #{author}")
        end)
      {:error, error} ->
        IO.puts("   Search error: #{error}")
    end
  {:error, error} ->
    IO.puts("   Query creation error: #{error}")
end

# Test 3: Test our string parser for this specific case
IO.puts("\n3. Testing string parser logic:")
query_str = "author:\"Jane Doe\""
IO.puts("   Query string: #{query_str}")

# Manually parse like our parser does
case String.split(query_str, ":", parts: 2) do
  [field_name, term] ->
    field_name = String.trim(field_name)
    term = String.trim(term)
    
    IO.puts("   Field: '#{field_name}'")
    IO.puts("   Term before quote removal: '#{term}'")
    
    # Handle quoted terms
    term = if String.starts_with?(term, "\"") and String.ends_with?(term, "\"") do
      String.slice(term, 1..-2//-1)
    else
      term
    end
    
    IO.puts("   Term after quote removal: '#{term}'")
    IO.puts("   Contains space: #{String.contains?(term, " ")}")
    
    if String.contains?(term, " ") do
      words = String.split(term, " ") |> Enum.filter(&(String.length(&1) > 0))
      IO.puts("   Split into words: #{inspect(words)}")
      
      case Query.phrase(schema, field_name, words) do
        {:ok, query} ->
          IO.puts("   Phrase query created successfully")
          case Searcher.search(searcher, query, 10) do
            {:ok, results} ->
              IO.puts("   Manual phrase query results: #{length(results)}")
            {:error, error} ->
              IO.puts("   Manual phrase query error: #{error}")
          end
        {:error, error} ->
          IO.puts("   Manual phrase query creation error: #{error}")
      end
    end
end

# Test 4: Test the full string search
IO.puts("\n4. Testing full string search:")
case Searcher.search_with_schema(searcher, "author:\"Jane Doe\"", schema, 10) do
  {:ok, results} ->
    IO.puts("   String search results: #{length(results)}")
  {:error, error} ->
    IO.puts("   String search error: #{error}")
end

IO.puts("\n=== DEBUG COMPLETE ===")