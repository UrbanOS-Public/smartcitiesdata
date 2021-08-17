# Raptor

To start Raptor locally:

  * Install dependencies with `mix deps.get`
  * Run `MIX_ENV=integration mix docker.start`
  * Run `MIX_ENV=integration iex -S mix start`

Now you can visit [`localhost:4000`](http://localhost:4000/healthcheck) from your browser.
