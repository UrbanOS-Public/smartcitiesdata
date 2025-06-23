# Start ExUnit
ExUnit.start()

# Load all test support files
support_path = Path.join([__DIR__, "support"])

if File.dir?(support_path) do
  support_path
  |> File.ls!()
  |> Enum.filter(&String.ends_with?(&1, ".ex"))
  |> Enum.each(fn file ->
    file_path = Path.join(support_path, file)
    Code.require_file(file_path)
  end)
end

import TelemetryEvent.MyTestHelper
