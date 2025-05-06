import Config

config :dead_letter,
  driver: [
    module: DeadLetter.Carrier.Test,
    init_args: [size: 3_000]
  ]
