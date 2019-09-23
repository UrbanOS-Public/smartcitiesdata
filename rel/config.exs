~w(rel plugins *.exs)
|> Path.join()
|> Path.wildcard()
|> Enum.map(&Code.eval_file(&1))

use Distillery.Releases.Config,
    default_release: :default,
    default_environment: Mix.env()

environment :dev do
  set dev_mode: true
  set include_erts: false
  set cookie: :"_q24F/BBb@JBm)P%lZ~ign&WJ:]:TaT3i5M)ARX>^Sv$1@5!8vdEWb3uuTpj4pH<"
end

environment :prod do
  set include_erts: true
  set include_src: false
  set cookie: :"UmFgS>>q;?q`kquWZ`G=c!4/Qrug]c]EuL}9koyB}a)=R)E|H>4Q(t$H`0f8)OZ~"
  set vm_args: "rel/vm.args"
  set config_providers: [{Distillery.Releases.Config.Providers.Elixir, ["${RELEASE_ROOT_DIR}/etc/runtime.exs"]}]
  set pre_configure_hooks: "rel/hooks/pre_configure.d"
end

release :andi do
  set version: current_version(:andi)
  set applications: [:runtime_tools, :andi]
  set overlays: [{:copy, "apps/andi/runtime.exs", "etc/runtime.exs"}]
end

release :flair do
  set version: current_version(:flair)
  set applications: [:runtime_tools, :flair]
  set overlays: [{:copy, "apps/flair/runtime.exs", "etc/runtime.exs"}]
end

release :forklift do
  set version: current_version(:forklift)
  set applications: [:runtime_tools, :forklift]
  set overlays: [{:copy, "apps/forklift/runtime.exs", "etc/runtime.exs"}]
end
