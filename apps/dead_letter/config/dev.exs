use Mix.Config

config :dead_letter,
  driver: [module: DeadLetter.Carrier.Test]
