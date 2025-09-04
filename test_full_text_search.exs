# TantivyEx.FullTextSearch GenServer Demo and Test
# 
# This file demonstrates the FullTextSearch GenServer with comprehensive
# testing of all features and sample data.
#
# Run with: elixir -S mix run test_full_text_search.exs

alias TantivyEx.FullTextSearch

defmodule FullTextSearchDemo do
  @moduledoc """
  Comprehensive demo and test suite for TantivyEx.FullTextSearch GenServer.
  """
  
  def run do
    IO.puts("🚀 TantivyEx.FullTextSearch GenServer Demo")
    IO.puts(String.duplicate("=", 60))
    
    # Test 1: Start the service
    test_service_startup()
    
    # Test 2: Add sample data
    test_document_operations()
    
    # Test 3: Search operations
    test_search_operations()
    
    # Test 4: Advanced operations
    test_advanced_operations()
    
    # Test 5: Error handling
    test_error_handling()
    
    # Test 6: Performance with larger dataset
    test_performance()
    
    IO.puts("\n🎉 All tests completed!")
    interactive_mode()
  end
  
  defp test_service_startup do
    IO.puts("\n📋 Test 1: Service Startup")
    IO.puts(String.duplicate("-", 30))
    
    case FullTextSearch.start_link(name: :demo_search) do
      {:ok, pid} ->
        IO.puts("✅ Service started successfully (PID: #{inspect(pid)})")
        
        # Test stats on empty index
        case FullTextSearch.stats(:demo_search) do
          {:ok, stats} ->
            IO.puts("✅ Initial stats: #{stats.document_count} documents")
          error ->
            IO.puts("❌ Stats error: #{inspect(error)}")
        end
        
      error ->
        IO.puts("❌ Failed to start service: #{inspect(error)}")
    end
  end
  
  defp test_document_operations do
    IO.puts("\n📝 Test 2: Document Operations")
    IO.puts(String.duplicate("-", 35))
    
    # Generate rich sample data
    sample_docs = generate_sample_data()
    
    # Test adding multiple documents
    IO.puts("Adding #{length(sample_docs)} sample documents...")
    case FullTextSearch.add_documents(:demo_search, sample_docs) do
      {:ok, count} ->
        IO.puts("✅ Added #{count} documents successfully")
      error ->
        IO.puts("❌ Batch add failed: #{inspect(error)}")
    end
    
    # Test adding a single document
    IO.puts("Adding one additional document...")
    new_doc = %{
      "id" => 999,
      "title" => "Dynamic Document Addition",
      "content" => "This document was added dynamically to test the add_document function.",
      "author" => "Test Author",
      "category" => "Testing",
      "tags" => "dynamic testing realtime",
      "rating" => 4,
      "published_at" => "2024-04-01",
      "price" => 19.99
    }
    
    case FullTextSearch.add_document(:demo_search, new_doc) do
      {:ok, :added} ->
        IO.puts("✅ Single document added successfully")
      error ->
        IO.puts("❌ Single add failed: #{inspect(error)}")
    end
    
    # Check final document count
    case FullTextSearch.stats(:demo_search) do
      {:ok, stats} ->
        IO.puts("✅ Total documents in index: #{stats.document_count}")
      error ->
        IO.puts("❌ Stats check failed: #{inspect(error)}")
    end
  end
  
  defp test_search_operations do
    IO.puts("\n🔍 Test 3: Search Operations")
    IO.puts(String.duplicate("-", 32))
    
    search_tests = [
      # Simple searches
      {"elixir", "Simple search for programming language"},
      {"web", "Search for web-related content"},
      {"performance", "Search for performance content"},
      
      # Field-specific searches
      {"Jane Doe", "Multi-word author search"},
      {"Programming", "Category search"},
      {"5", "Rating search"},
      
      # Boolean searches (using service methods)
      {["elixir", "functional"], :and, "Boolean AND search"},
      {["rust", "phoenix"], :or, "Boolean OR search"},
      {["programming", "guide"], :and, "Programming guides"},
      
      # Edge cases
      {"nonexistent", "Non-existent term search"},
      {"", "Empty search"},
      {"*", "Wildcard search"}
    ]
    
    Enum.each(search_tests, fn
      {query, description} when is_binary(query) ->
        test_simple_search(query, description)
        
      {terms, :and, description} ->
        test_boolean_and_search(terms, description)
        
      {terms, :or, description} ->
        test_boolean_or_search(terms, description)
    end)
  end
  
  defp test_advanced_operations do
    IO.puts("\n⚙️ Test 4: Advanced Operations")
    IO.puts(String.duplicate("-", 35))
    
    # Test field-specific searches
    field_tests = [
      {"author", "Jane", "Author field search"},
      {"category", "Programming", "Category field search"},
      {"rating", "5", "Rating field search"},
      {"tags", "realtime", "Tags field search"}
    ]
    
    Enum.each(field_tests, fn {field, term, description} ->
      IO.puts("\n#{description}:")
      case FullTextSearch.search_field(:demo_search, field, term) do
        {:ok, results} ->
          IO.puts("✅ Found #{length(results)} result(s)")
          show_top_results(results, 2)
        error ->
          IO.puts("❌ Error: #{inspect(error)}")
      end
    end)
    
    # Test getting all documents
    IO.puts("\nRetrieving all documents:")
    case FullTextSearch.get_all_documents(:demo_search, 20) do
      {:ok, all_docs} ->
        IO.puts("✅ Retrieved #{length(all_docs)} total documents")
        
        # Show document distribution by category
        categories = Enum.group_by(all_docs, &Map.get(&1, "category", "Unknown"))
        IO.puts("📊 Documents by category:")
        Enum.each(categories, fn {cat, docs} ->
          IO.puts("   📂 #{cat}: #{length(docs)} document(s)")
        end)
        
      error ->
        IO.puts("❌ Error retrieving all documents: #{inspect(error)}")
    end
  end
  
  defp test_error_handling do
    IO.puts("\n🛡️ Test 5: Error Handling")
    IO.puts(String.duplicate("-", 30))
    
    # Test document deletion (should fail gracefully)
    IO.puts("Testing document deletion (expected to fail):")
    case FullTextSearch.delete_document(:demo_search, 1) do
      {:ok, _} ->
        IO.puts("⚠️ Unexpected success - deletion should not be implemented")
      {:error, reason} ->
        IO.puts("✅ Expected error: #{reason}")
    end
    
    # Test invalid field search
    IO.puts("\nTesting search on non-existent field:")
    case FullTextSearch.search_field(:demo_search, "nonexistent_field", "test") do
      {:ok, results} ->
        IO.puts("⚠️ Unexpected success: #{length(results)} results")
      {:error, reason} ->
        IO.puts("✅ Handled gracefully: #{reason}")
    end
  end
  
  defp test_performance do
    IO.puts("\n⚡ Test 6: Performance Test")
    IO.puts(String.duplicate("-", 30))
    
    # Add more documents for performance testing
    IO.puts("Generating 50 additional documents for performance testing...")
    
    perf_docs = Enum.map(1..50, fn i ->
      categories = ["Tech", "Science", "Business", "Education", "Entertainment"]
      authors = ["John Smith", "Jane Doe", "Bob Wilson", "Alice Johnson", "Carol Brown"]
      
      %{
        "id" => 1000 + i,
        "title" => "Performance Test Document #{i}",
        "content" => "This is performance test document number #{i}. It contains various keywords like technology, innovation, and development for testing search performance.",
        "author" => Enum.random(authors),
        "category" => Enum.random(categories),
        "tags" => "performance test document #{i}",
        "rating" => Enum.random(1..5),
        "published_at" => "2024-04-#{rem(i, 28) + 1}",
        "price" => Float.round(:rand.uniform() * 100, 2)
      }
    end)
    
    # Measure batch insertion time
    start_time = System.monotonic_time(:millisecond)
    case FullTextSearch.add_documents(:demo_search, perf_docs) do
      {:ok, count} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time
        IO.puts("✅ Added #{count} documents in #{duration}ms")
        IO.puts("📊 Average: #{Float.round(duration / count, 2)}ms per document")
        
        # Test search performance
        test_search_performance()
        
      error ->
        IO.puts("❌ Performance test failed: #{inspect(error)}")
    end
  end
  
  defp test_search_performance do
    search_queries = [
      "technology",
      "document",
      "performance",
      "author:Jane",
      "category:Tech",
      "rating:5"
    ]
    
    IO.puts("\nTesting search performance:")
    total_time = Enum.reduce(search_queries, 0, fn query, acc ->
      start_time = System.monotonic_time(:microsecond)
      
      case FullTextSearch.search(:demo_search, query, 20) do
        {:ok, results} ->
          end_time = System.monotonic_time(:microsecond)
          duration = div(end_time - start_time, 1000)  # Convert to milliseconds
          IO.puts("   '#{query}': #{length(results)} results in #{duration}ms")
          acc + duration
        error ->
          IO.puts("   '#{query}': Error - #{inspect(error)}")
          acc
      end
    end)
    
    avg_time = Float.round(total_time / length(search_queries), 1)
    IO.puts("📈 Average search time: #{avg_time}ms")
  end
  
  defp test_simple_search(query, description) do
    IO.puts("\n#{description} ('#{query}'):")
    case FullTextSearch.search(:demo_search, query) do
      {:ok, results} ->
        IO.puts("✅ Found #{length(results)} result(s)")
        show_top_results(results, 2)
      error ->
        IO.puts("❌ Error: #{inspect(error)}")
    end
  end
  
  defp test_boolean_and_search(terms, description) do
    IO.puts("\n#{description} (#{Enum.join(terms, " AND ")}):")
    case FullTextSearch.search_and(:demo_search, terms) do
      {:ok, results} ->
        IO.puts("✅ Found #{length(results)} result(s)")
        show_top_results(results, 2)
      error ->
        IO.puts("❌ Error: #{inspect(error)}")
    end
  end
  
  defp test_boolean_or_search(terms, description) do
    IO.puts("\n#{description} (#{Enum.join(terms, " OR ")}):")
    case FullTextSearch.search_or(:demo_search, terms) do
      {:ok, results} ->
        IO.puts("✅ Found #{length(results)} result(s)")
        show_top_results(results, 2)
      error ->
        IO.puts("❌ Error: #{inspect(error)}")
    end
  end
  
  defp show_top_results(results, limit) do
    results
    |> Enum.take(limit)
    |> Enum.with_index(1)
    |> Enum.each(fn {result, idx} ->
      title = Map.get(result, "title", "No title")
      author = Map.get(result, "author", "Unknown")
      rating = Map.get(result, "rating", 0)
      IO.puts("   #{idx}. #{title} by #{author} (⭐ #{rating})")
    end)
  end
  
  defp generate_sample_data do
    [
      %{
        "id" => 1,
        "title" => "Getting Started with Elixir",
        "content" => "Elixir is a dynamic, functional language designed for building maintainable and scalable applications. It leverages the Erlang Virtual Machine (BEAM), giving you a distributed, fault-tolerant system with hot code swapping.",
        "author" => "Jane Doe",
        "category" => "Programming",
        "tags" => "elixir functional programming beginner tutorial",
        "rating" => 5,
        "published_at" => "2024-01-15",
        "price" => 29.99
      },
      %{
        "id" => 2,
        "title" => "Phoenix Web Development Framework",
        "content" => "Phoenix is a web development framework written in Elixir. It provides high developer productivity and application performance through real-time features like Channels and LiveView.",
        "author" => "John Smith",
        "category" => "Web Development",
        "tags" => "phoenix elixir web framework realtime channels liveview",
        "rating" => 4,
        "published_at" => "2024-02-10",
        "price" => 39.99
      },
      %{
        "id" => 3,
        "title" => "Rust Performance Programming Guide",
        "content" => "Rust is a systems programming language that runs blazingly fast, prevents segfaults, and guarantees memory safety. Perfect for performance-critical applications and system programming.",
        "author" => "Alice Johnson",
        "category" => "Systems Programming",
        "tags" => "rust performance systems memory-safety zero-cost",
        "rating" => 5,
        "published_at" => "2024-01-20",
        "price" => 49.99
      },
      %{
        "id" => 4,
        "title" => "Functional Programming Principles and Patterns",
        "content" => "Learn the core principles of functional programming including immutability, pattern matching, and higher-order functions. Applicable to many languages including Elixir, Haskell, and F#.",
        "author" => "Bob Wilson",
        "category" => "Programming",
        "tags" => "functional programming theory principles patterns immutability",
        "rating" => 4,
        "published_at" => "2024-03-05",
        "price" => 34.99
      },
      %{
        "id" => 5,
        "title" => "Building Real-time Systems with Elixir and OTP",
        "content" => "Master building distributed, fault-tolerant real-time systems using Elixir and OTP. Covers GenServers, supervision trees, distributed architectures, and scalability patterns.",
        "author" => "Carol Brown",
        "category" => "Distributed Systems",
        "tags" => "elixir otp realtime distributed genserver supervision scalability",
        "rating" => 5,
        "published_at" => "2024-02-28",
        "price" => 44.99
      },
      %{
        "id" => 6,
        "title" => "Modern JavaScript and React Development",
        "content" => "Comprehensive guide to modern JavaScript development with React, including hooks, context, state management, and performance optimization techniques.",
        "author" => "Emma Davis",
        "category" => "Web Development",
        "tags" => "javascript react frontend hooks state-management performance",
        "rating" => 4,
        "published_at" => "2024-03-12",
        "price" => 42.50
      },
      %{
        "id" => 7,
        "title" => "Database Design and Optimization",
        "content" => "Learn database design principles, normalization, indexing strategies, and query optimization for both SQL and NoSQL databases. Includes performance tuning tips.",
        "author" => "Michael Chen",
        "category" => "Database",
        "tags" => "database sql nosql optimization indexing performance design",
        "rating" => 4,
        "published_at" => "2024-01-30",
        "price" => 38.99
      },
      %{
        "id" => 8,
        "title" => "Machine Learning with Python and TensorFlow",
        "content" => "Practical machine learning guide using Python and TensorFlow. Covers neural networks, deep learning, data preprocessing, and model deployment in production.",
        "author" => "Sarah Kim",
        "category" => "Machine Learning",
        "tags" => "python tensorflow machine-learning neural-networks deep-learning ai",
        "rating" => 5,
        "published_at" => "2024-02-15",
        "price" => 59.99
      }
    ]
  end
  
  defp test_search_operations do
    IO.puts("\n🔍 Test 3: Search Operations")
    IO.puts(String.duplicate("-", 32))
    
    # Test simple searches
    simple_searches = [
      {"elixir", "Should find Elixir-related documents"},
      {"performance", "Should find performance-related content"},
      {"web", "Should find web development content"},
      {"database", "Should find database content"},
      {"nonexistent", "Should return no results"}
    ]
    
    IO.puts("🔹 Simple Text Searches:")
    Enum.each(simple_searches, fn {query, description} ->
      IO.puts("\n   Query: '#{query}' - #{description}")
      case FullTextSearch.search(:demo_search, query, 5) do
        {:ok, results} ->
          IO.puts("   ✅ Found #{length(results)} result(s)")
          show_top_results_compact(results, 2)
        error ->
          IO.puts("   ❌ Error: #{inspect(error)}")
      end
    end)
    
    # Test field-specific searches
    field_searches = [
      {"author", "Jane Doe", "Multi-word author search"},
      {"category", "Programming", "Category search"},
      {"rating", "5", "High rating search"},
      {"tags", "realtime", "Tag search"}
    ]
    
    IO.puts("\n🔹 Field-Specific Searches:")
    Enum.each(field_searches, fn {field, term, description} ->
      IO.puts("\n   #{field}:#{term} - #{description}")
      case FullTextSearch.search_field(:demo_search, field, term, 3) do
        {:ok, results} ->
          IO.puts("   ✅ Found #{length(results)} result(s)")
          show_top_results_compact(results, 2)
        error ->
          IO.puts("   ❌ Error: #{inspect(error)}")
      end
    end)
    
    # Test boolean searches
    IO.puts("\n🔹 Boolean Searches:")
    
    IO.puts("\n   AND Search: elixir + programming")
    case FullTextSearch.search_and(:demo_search, ["elixir", "programming"]) do
      {:ok, results} ->
        IO.puts("   ✅ Found #{length(results)} result(s)")
        show_top_results_compact(results, 2)
      error ->
        IO.puts("   ❌ Error: #{inspect(error)}")
    end
    
    IO.puts("\n   OR Search: rust + javascript")
    case FullTextSearch.search_or(:demo_search, ["rust", "javascript"]) do
      {:ok, results} ->
        IO.puts("   ✅ Found #{length(results)} result(s)")
        show_top_results_compact(results, 2)
      error ->
        IO.puts("   ❌ Error: #{inspect(error)}")
    end
  end
  
  defp test_error_handling do
    IO.puts("\n🛡️ Test 4: Error Handling")
    IO.puts(String.duplicate("-", 30))
    
    # Test various error conditions
    error_tests = [
      {"Document deletion", fn -> FullTextSearch.delete_document(:demo_search, 1) end},
      {"Invalid server name", fn -> FullTextSearch.search(:nonexistent_server, "test") end},
      {"Empty document", fn -> FullTextSearch.add_document(:demo_search, %{}) end}
    ]
    
    Enum.each(error_tests, fn {test_name, test_fn} ->
      IO.puts("\n#{test_name}:")
      case test_fn.() do
        {:ok, result} ->
          IO.puts("   ⚠️ Unexpected success: #{inspect(result)}")
        {:error, reason} ->
          IO.puts("   ✅ Handled gracefully: #{reason}")
        :exit ->
          IO.puts("   ✅ Process exit handled gracefully")
      end
    end)
  end
  
  defp test_performance do
    IO.puts("\n⚡ Test 5: Performance Test")
    IO.puts(String.duplicate("-", 30))
    
    # Test current performance with existing documents
    performance_queries = [
      "programming",
      "elixir",
      "author:Jane",
      "category:Programming",
      "*"
    ]
    
    IO.puts("Testing search performance with current dataset:")
    
    total_time = Enum.reduce(performance_queries, 0, fn query, acc ->
      start_time = System.monotonic_time(:microsecond)
      
      case FullTextSearch.search(:demo_search, query, 10) do
        {:ok, results} ->
          end_time = System.monotonic_time(:microsecond)
          duration = div(end_time - start_time, 1000)  # Convert to milliseconds
          IO.puts("   '#{query}': #{length(results)} results in #{duration}ms")
          acc + duration
        error ->
          IO.puts("   '#{query}': Error - #{inspect(error)}")
          acc
      end
    end)
    
    avg_time = Float.round(total_time / length(performance_queries), 1)
    IO.puts("📈 Average search time: #{avg_time}ms")
    
    # Show final statistics
    case FullTextSearch.stats(:demo_search) do
      {:ok, stats} ->
        IO.puts("📊 Final index statistics:")
        IO.puts("   📄 Total documents: #{stats.document_count}")
        IO.puts("   🏷️  Schema fields: #{length(stats.schema_fields)}")
        IO.puts("   💾 Index type: #{stats.index_type}")
        IO.puts("   🧠 Writer memory: #{div(stats.writer_memory, 1_000_000)}MB")
      error ->
        IO.puts("❌ Stats error: #{inspect(error)}")
    end
  end
  
  defp show_top_results_compact(results, limit) do
    results
    |> Enum.take(limit)
    |> Enum.with_index(1)
    |> Enum.each(fn {result, idx} ->
      title = Map.get(result, "title", "No title") |> String.slice(0, 40)
      author = Map.get(result, "author", "Unknown")
      IO.puts("      #{idx}. #{title}... by #{author}")
    end)
  end
  
  defp interactive_mode do
    IO.puts("\n🎮 Interactive Mode Available!")
    IO.puts(String.duplicate("=", 40))
    IO.puts("The search service is running. Try these commands:")
    IO.puts("")
    IO.puts("💡 Quick searches:")
    IO.puts("   TantivyEx.FullTextSearch.search(:demo_search, \"elixir\")")
    IO.puts("   TantivyEx.FullTextSearch.search(:demo_search, \"author:Jane\")")
    IO.puts("")
    IO.puts("💡 Advanced searches:")
    IO.puts("   TantivyEx.FullTextSearch.search_and(:demo_search, [\"elixir\", \"programming\"])")
    IO.puts("   TantivyEx.FullTextSearch.search_or(:demo_search, [\"rust\", \"javascript\"])")
    IO.puts("")
    IO.puts("💡 Utility functions:")
    IO.puts("   TantivyEx.FullTextSearch.stats(:demo_search)")
    IO.puts("   TantivyEx.FullTextSearch.get_all_documents(:demo_search)")
    IO.puts("")
    IO.puts("🎯 Example: Try searching for 'machine learning' or 'real-time'")
  end
end

# Run the comprehensive demo
FullTextSearchDemo.run()