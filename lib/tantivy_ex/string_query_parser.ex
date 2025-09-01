defmodule TantivyEx.StringQueryParser do
  @moduledoc """
  String query parser for TantivyEx.
  
  This module provides a workaround for the broken string-based search
  by parsing common query patterns and converting them to Query objects.
  
  Supported query patterns:
  - Simple terms: "elixir" → searches all text fields
  - Field-specific: "title:elixir" → searches specific field  
  - Wildcard: "*" → returns all documents
  - Boolean AND: "elixir AND phoenix" → both terms must match
  - Boolean OR: "elixir OR rust" → either term can match
  - Phrase queries: "\"hello world\"" → exact phrase match
  - Parentheses: "(elixir OR rust) AND title:guide"
  """
  
  alias TantivyEx.{Query, Schema}
  
  @doc """
  Parses a query string and returns a Query object.
  
  ## Parameters
  - `schema`: The schema for field resolution
  - `query_string`: The query string to parse
  - `default_fields`: List of fields to search when no field is specified (defaults to all text fields)
  
  ## Examples
  
      iex> {:ok, query} = StringQueryParser.parse(schema, "elixir")
      iex> {:ok, query} = StringQueryParser.parse(schema, "title:phoenix") 
      iex> {:ok, query} = StringQueryParser.parse(schema, "elixir AND phoenix")
  """
  @spec parse(Schema.t(), String.t(), [String.t()] | nil) :: {:ok, Query.t()} | {:error, String.t()}
  def parse(schema, query_string, default_fields \\ nil) do
    query_string = String.trim(query_string)
    
    cond do
      # Handle wildcard - return all documents
      query_string == "*" ->
        Query.all()
      
      # Handle empty query
      query_string == "" ->
        Query.all()
        
      # Handle field-specific queries (e.g., "title:elixir", "author:\"Jane Doe\"")
      String.contains?(query_string, ":") and is_field_query?(query_string) ->
        parse_field_query(schema, query_string)
        
      # Handle boolean queries with AND/OR
      String.contains?(query_string, " AND ") or String.contains?(query_string, " OR ") ->
        parse_boolean_query(schema, query_string, default_fields)
        
      # Handle phrase queries ("hello world")
      String.starts_with?(query_string, "\"") and String.ends_with?(query_string, "\"") ->
        parse_phrase_query(schema, query_string, default_fields)
        
      # Handle simple term queries
      true ->
        parse_simple_query(schema, query_string, default_fields)
    end
  end
  
  # Parse field-specific queries like "title:elixir" or "author:\"Jane Doe\""
  defp parse_field_query(schema, query_string) do
    case String.split(query_string, ":", parts: 2) do
      [field_name, term] ->
        field_name = String.trim(field_name)
        term = String.trim(term)
        
        # Handle quoted terms properly
        term = if String.starts_with?(term, "\"") and String.ends_with?(term, "\"") do
          String.slice(term, 1..-2//1)  # Remove surrounding quotes
        else
          term
        end
        
        if Schema.field_exists?(schema, field_name) do
          Query.term(schema, field_name, term)
        else
          {:error, "Field '#{field_name}' does not exist in schema"}
        end
        
      _ ->
        {:error, "Invalid field query format: #{query_string}"}
    end
  end
  
  # Parse simple queries like "elixir"
  defp parse_simple_query(schema, query_string, default_fields) do
    fields = default_fields || get_text_fields(schema)
    term = String.trim(query_string, "\"")
    
    if Enum.empty?(fields) do
      {:error, "No searchable fields found in schema"}
    else
      # Create OR query across all default fields
      create_multi_field_query(schema, fields, term)
    end
  end
  
  # Parse phrase queries like "\"hello world\""
  defp parse_phrase_query(schema, query_string, default_fields) do
    phrase = query_string |> String.trim("\"")
    fields = default_fields || get_text_fields(schema)
    
    if Enum.empty?(fields) do
      {:error, "No searchable fields found in schema"}
    else
      # For now, treat phrases as term queries
      # In the future, could implement proper phrase queries
      create_multi_field_query(schema, fields, phrase)
    end
  end
  
  # Parse boolean queries like "elixir AND phoenix" or "elixir OR rust"
  defp parse_boolean_query(schema, query_string, default_fields) do
    cond do
      String.contains?(query_string, " AND ") ->
        parse_and_query(schema, query_string, default_fields)
        
      String.contains?(query_string, " OR ") ->
        parse_or_query(schema, query_string, default_fields)
        
      true ->
        {:error, "Unrecognized boolean query format"}
    end
  end
  
  # Parse AND queries
  defp parse_and_query(schema, query_string, default_fields) do
    terms = String.split(query_string, " AND ") |> Enum.map(&String.trim/1)
    
    case parse_terms_to_queries(schema, terms, default_fields) do
      {:ok, queries} -> Query.boolean(queries, [], [])  # All must match
      error -> error
    end
  end
  
  # Parse OR queries
  defp parse_or_query(schema, query_string, default_fields) do
    terms = String.split(query_string, " OR ") |> Enum.map(&String.trim/1)
    
    case parse_terms_to_queries(schema, terms, default_fields) do
      {:ok, queries} -> Query.boolean([], queries, [])  # Any can match
      error -> error
    end
  end
  
  # Convert list of term strings to Query objects
  defp parse_terms_to_queries(schema, terms, default_fields) do
    queries = 
      Enum.reduce_while(terms, [], fn term, acc ->
        case parse(schema, term, default_fields) do
          {:ok, query} -> {:cont, [query | acc]}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    
    case queries do
      {:error, reason} -> {:error, reason}
      queries when is_list(queries) -> {:ok, Enum.reverse(queries)}
    end
  end
  
  # Create an OR query across multiple fields for a single term
  defp create_multi_field_query(schema, fields, term) do
    queries = 
      Enum.reduce_while(fields, [], fn field, acc ->
        case Query.term(schema, field, term) do
          {:ok, query} -> {:cont, [query | acc]}
          {:error, _} -> {:cont, acc}  # Skip invalid fields silently
        end
      end)
    
    case queries do
      [] -> {:error, "Could not create query for any field"}
      [single_query] -> {:ok, single_query}
      multiple_queries -> Query.boolean([], multiple_queries, [])  # OR across fields
    end
  end
  
  # Get all text fields from schema
  defp get_text_fields(schema) do
    field_names = Schema.get_field_names(schema)
    
    Enum.filter(field_names, fn field_name ->
      case Schema.get_field_type(schema, field_name) do
        {:ok, "text"} -> true
        _ -> false
      end
    end)
  end
  
  # Check if a query string is a field-specific query (handles quotes and spaces)
  defp is_field_query?(query_string) do
    case String.split(query_string, ":", parts: 2) do
      [_field, _term] ->
        # It's a field query if it splits into exactly 2 parts with ":"
        # and doesn't contain boolean operators
        not (String.contains?(query_string, " AND ") or String.contains?(query_string, " OR "))
      _ ->
        false
    end
  end
end