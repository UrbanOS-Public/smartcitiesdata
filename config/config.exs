# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Config

# By default, the umbrella project as well as each child
# application will require this configuration file, as
# configuration and dependencies are shared in an umbrella
# project. While one could configure all applications here,
# we prefer to keep the configuration of each individual
# child application in their own app, but all other
# dependencies, regardless if they belong to one or multiple
# apps, should be configured in the umbrella to avoid confusion.
for config <- "../apps/*/config/config.exs" |> Path.expand(__DIR__) |> Path.wildcard() do
  import_config config
end

# Sample configuration (overrides the imported configuration above):
#
#     config :logger, :console,
#       level: :info,
#       format: "$date $time [$level] $metadata$message\n",
#       metadata: [:user_id]

config :mime, :types, %{
  "application/gtfs+protobuf" => ["gtfs"],
  "application/zip" => ["zip", "shp", "shapefile"],
  "application/vnd.ogc.wms_xml" => ["wms"]
}

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase
config :json_serde, :type_key, "__type__"
# config :brook, :serializer, JsonSerde

config :phoenix,
  template_engines: [leex: Phoenix.LiveView.Engine]

config :estuary, prestige: Prestige.Mock
