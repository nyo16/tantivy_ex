# Advanced Queries Guide

This guide demonstrates TantivyEx's advanced query capabilities, providing full access to Tantivy's powerful search functionality with idiomatic Elixir APIs.

## Overview

TantivyEx exposes the complete Tantivy query API, allowing you to build complex search queries with the same flexibility as the Rust Tantivy library. All query types support composition, boolean operations, and advanced features like phrase prefix matching and boosted scoring.

## Setup Requirements

For full functionality, ensure your schema fields use `:fast_stored` options:

```elixir
alias TantivyEx.{Schema, Index, IndexWriter, Searcher, Query}

# Create schema with :fast_stored fields for full functionality
schema = Schema.new()
         |> Schema.add_text_field("title", :fast_stored)
         |> Schema.add_text_field("body", :fast_stored)
         |> Schema.add_text_field("author", :fast_stored)

{:ok, index} = Index.create_in_ram(schema)
{:ok, writer} = IndexWriter.new(index, 50_000_000)
{:ok, searcher} = Searcher.new(index)
```

## Native QueryParser

TantivyEx provides a native QueryParser that mirrors Rust's `QueryParser::for_index(&index, vec![field1, field2])`:

```elixir
# Create parser for specific fields
{:ok, parser} = Query.parser(index, ["title", "body"])

# Parse and execute various query types
queries = [
  "rust",                                    # Simple term search
  "title:rust",                             # Field-specific search
  "rust AND programming",                   # Boolean AND
  "title:getting^10 body:programming^5",   # Boosted scoring
  "(rust OR elixir) AND programming"       # Complex boolean
]

Enum.each(queries, fn query_str ->
  case Query.parse(parser, query_str) do
    {:ok, query} ->
      {:ok, results} = Searcher.search(searcher, query, 10)
      IO.puts("'#{query_str}' → #{length(results)} result(s)")
    {:error, err} ->
      IO.puts("Parse error: #{err}")
  end
end)
```

## Phrase Prefix Queries

Phrase prefix queries allow matching phrases where the last term is a prefix (equivalent to Rust's `"in the su"*` syntax):

### Method 1: Direct Construction

```elixir
# Find documents containing "getting started" where "started" matches the prefix "star"
phrase_terms = ["getting"]
prefix_term = "star"

{:ok, query} = Query.phrase_with_prefix(schema, "body", phrase_terms, prefix_term)
{:ok, results} = Searcher.search(searcher, query, 10)
```

### Method 2: Parse Helper

```elixir
# Parse phrase prefix using query string syntax
query_string = "\"getting star\"*"
{:ok, query} = Query.parse_phrase_prefix(schema, "body", query_string)
{:ok, results} = Searcher.search(searcher, query, 10)
```

## Complete Query Types

TantivyEx exposes all Tantivy query types:

### Basic Queries

```elixir
# Term Query - exact term match
{:ok, query} = Query.term(schema, "author", "Jane Smith")

# Phrase Query - exact phrase match
{:ok, query} = Query.phrase(schema, "title", ["Getting", "Started"])

# All Documents Query
{:ok, query} = Query.all()
```

### Pattern Matching

```elixir
# Regex Query
{:ok, query} = Query.regex(schema, "title", ".*Rust.*")

# Wildcard Query
{:ok, query} = Query.wildcard(schema, "title", "*Started*")
```

### Boolean Composition

```elixir
# Boolean AND
with {:ok, q1} <- Query.term(schema, "title", "rust"),
     {:ok, q2} <- Query.term(schema, "body", "programming") do
  {:ok, and_query} = Query.boolean([q1, q2], [], [])  # [must], [should], [must_not]
end

# Boolean OR
with {:ok, q1} <- Query.term(schema, "title", "rust"),
     {:ok, q2} <- Query.term(schema, "title", "elixir") do
  {:ok, or_query} = Query.boolean([], [q1, q2], [])  # Empty must, q1 OR q2 in should
end
```

## Complex Composed Queries

Build sophisticated queries by combining multiple query types:

```elixir
# Complex query: (rust OR elixir) AND "programming language"
with {:ok, rust_term} <- Query.term(schema, "title", "rust"),
     {:ok, elixir_term} <- Query.term(schema, "title", "elixir"),
     {:ok, programming_phrase} <- Query.phrase(schema, "body", ["programming", "language"]),
     {:ok, language_or} <- Query.boolean([], [rust_term, elixir_term], []),  # rust OR elixir
     {:ok, final_query} <- Query.boolean([language_or, programming_phrase], [], []) do  # (rust OR elixir) AND "programming language"
  
  {:ok, results} = Searcher.search(searcher, final_query, 10)
  IO.puts("Found #{length(results)} documents matching complex query")
end
```

## Query Scoring and Boosting

Use the QueryParser with boost syntax for advanced scoring:

```elixir
{:ok, parser} = Query.parser(index, ["title", "body"])

# Boost title matches 10x and body matches 5x
query_str = "title:getting^10 body:programming^5"
{:ok, query} = Query.parse(parser, query_str)
{:ok, results} = Searcher.search(searcher, query, 10)
```

## Error Handling

All query operations return `{:ok, result}` or `{:error, reason}` tuples:

```elixir
case Query.parse(parser, "invalid:query:syntax") do
  {:ok, query} ->
    # Proceed with search
    Searcher.search(searcher, query, 10)
  {:error, reason} ->
    # Handle parse error
    IO.puts("Query parse failed: #{reason}")
end
```

## Best Practices

1. **Use `:fast_stored` fields** for full query functionality
2. **Validate user input** before parsing queries
3. **Compose queries step by step** for complex searches
4. **Handle errors gracefully** with pattern matching
5. **Use appropriate query types** for your use case:
   - Term queries for exact matches
   - Phrase queries for exact phrase matches
   - Regex/Wildcard for pattern matching
   - Boolean queries for combining conditions
   - Parser queries for user-generated searches

## Performance Considerations

- **QueryParser** queries are parsed at runtime - consider caching for repeated queries
- **Direct query construction** (Term, Phrase, etc.) is faster for known query patterns
- **Boolean queries** with many clauses may impact performance
- **Regex queries** are powerful but can be slow on large datasets

This advanced query system provides the same flexibility and power as Rust Tantivy while maintaining Elixir's ergonomic patterns and error handling conventions.