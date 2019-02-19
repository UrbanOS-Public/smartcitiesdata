# Import all plugins from `rel/plugins`
# They can then be used by adding `plugin MyPlugin` to
# either an environment, or release definition, where
# `MyPlugin` is the name of the plugin module.
~w(rel plugins *.exs)
|> Path.join()
|> Path.wildcard()
|> Enum.map(&Code.eval_file(&1))

use Mix.Releases.Config,
    # This sets the default release built by `mix release`
    default_release: :default,
    # This sets the default environment used by `mix release`
    default_environment: :prod

# For a full list of config options for both releases
# and environments, visit https://hexdocs.pm/distillery/config/distillery.html


# You may define one or more environments in this file,
# an environment's settings will override those of a release
# when building in that environment, this combination of release
# and environment configuration is called a profile

environment :prod do
  set vm_args: "rel/prod.vm.args"
  set include_erts: true
  set include_src: false
  set cookie: :"z^KU3`9hu>z[!&uU,[{}~sZFNxk(sV.IT.PB=B[;AXBU:o0:{=6!)sk2!nH$*)a)"
  set config_providers: [
    {Mix.Releases.Config.Providers.Elixir, ["${RELEASE_ROOT_DIR}/etc/runtime.exs"]}
  ]
  set pre_configure_hooks: "rel/hooks/pre_configure.d"
  set overlays: [
    {:copy, "rel/runtime.exs", "etc/runtime.exs"}
  ]
end

# You may define one or more releases in this file.
# If you have not set a default release, or selected one
# when running `mix release`, the first release in the file
# will be used by default

release :forklift do
  set version: current_version(:forklift)
  set applications: [
    :runtime_tools
  ]
end

config :kaffe,
  consumer: [
    endpoints: [localhost: 9092],
    topics: [System.get_env("DATA_TOPIC"), System.get_env("REGISTRY_TOPIC")],
    consumer_group: "forklift-group",
    message_handler: Forklift.MessageProcessor,
    offset_reset_policy: :reset_to_earliest,
    start_with_earliest_message: true,
    max_bytes: 1_000_000,
    worker_allocation_strategy: :worker_per_topic_partition,
  ]

config :forklift,
  timeout: 60_000,
  batch_size: 5_000,
  data_topic: System.get_env("DATA_TOPIC"),
  registry_topic: System.get_env("REGISTRY_TOPIC")
