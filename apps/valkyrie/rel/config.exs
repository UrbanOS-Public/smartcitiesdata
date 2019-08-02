~w(rel plugins *.exs)
|> Path.join()
|> Path.wildcard()
|> Enum.map(&Code.eval_file(&1))

use Distillery.Releases.Config,
    # This sets the default release built by `mix release`
    default_release: :default,
    # This sets the default environment used by `mix release`
    default_environment: :prod

# For a full list of config options for both releases
# and environments, visit https://hexdocs.pm/distillery/config/distillery.html

environment :prod do
  set vm_args: "rel/prod.vm.args"
  set include_erts: true
  set include_src: false
  set cookie: :"z^KU3`9hu>z[!&uU,[{}~sZFNxk(sV.IT.PB=B[;AXBU:o0:{=6!)sk2!nH$*)a)"
  set config_providers: [
    {Distillery.Releases.Config.Providers.Elixir, ["${RELEASE_ROOT_DIR}/etc/runtime.exs"]}
  ]
  set pre_configure_hooks: "rel/hooks/pre_configure.d"
  set overlays: [
    {:copy, "rel/runtime.exs", "etc/runtime.exs"}
  ]
end

release :valkyrie do
  set version: current_version(:valkyrie)
  set applications: [
    :runtime_tools
  ]
end
