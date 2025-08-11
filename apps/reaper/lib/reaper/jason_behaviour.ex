defmodule Reaper.JasonBehaviour do
  @callback encode(term()) :: {:ok, String.t()} | {:error, Exception.t()}
  @callback encode!(term()) :: String.t() | no_return()
  @callback decode(iodata()) :: {:ok, term()} | {:error, Exception.t()}
  @callback decode!(iodata()) :: term() | no_return()
end