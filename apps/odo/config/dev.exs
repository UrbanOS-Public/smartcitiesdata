use Mix.Config

config :odo, :brook,
  instance: :brook_test,
  handlers: [Odo.Event.EventHandler]
