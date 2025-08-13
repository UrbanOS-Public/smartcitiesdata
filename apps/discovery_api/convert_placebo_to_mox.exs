#!/usr/bin/env elixir

# Script to convert Placebo tests to Mox tests
# This does the basic conversions, but manual fixes may be needed for complex tests

import_regex = ~r/use Placebo/
setup_regex = ~r/allow\(([^,)]+)(?:\([^)]*\))?,\s*return:\s*([^)]+)\)/
assert_regex = ~r/assert_called\(([^)]+)\)/
refute_regex = ~r/refute_called\(([^)]+)\)/
exec_regex = ~r/allow\(([^,)]+)(?:\([^)]*\))?,\s*exec:\s*([^)]+)\)/

def convert_file(file_path) do
  content = File.read!(file_path)
  
  # Skip if already converted
  if String.contains?(content, "import Mox") do
    IO.puts("Skipping #{file_path} - already converted")
    return
  end
  
  # Skip if doesn't use Placebo
  unless String.contains?(content, "use Placebo") do
    IO.puts("Skipping #{file_path} - doesn't use Placebo")
    return
  end
  
  IO.puts("Converting #{file_path}")
  
  # Basic replacements
  new_content = content
    |> String.replace("use Placebo", "import Mox\n\n  setup :verify_on_exit!")
    # This would need to be much more sophisticated for a real conversion
    |> String.replace(~r/allow\(([^,)]+\([^)]*\)),\s*return:\s*([^)]+)\)/, "stub(MockModule, :function, fn _ -> \\2 end)")
    |> String.replace(~r/assert_called\(([^)]+)\)/, "# TODO: Convert assert_called(\\1)")
    |> String.replace(~r/refute_called\(([^)]+)\)/, "# TODO: Convert refute_called(\\1)")
  
  File.write!(file_path, new_content)
  IO.puts("Basic conversion completed for #{file_path}")
end

# Get all test files that use Placebo
test_files = Path.wildcard("/home/rseward/src/github/urbanos/smartcitiesdata/apps/discovery_api/test/**/*_test.exs")

Enum.each(test_files, &convert_file/1)

IO.puts("Basic conversion script completed. Manual fixes will be needed.")