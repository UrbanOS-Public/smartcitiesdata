import Config

# Import all app-level test configs
for config <- "apps/*/config/test.exs" |> Path.expand() |> Path.wildcard() do
  import_config config
end
