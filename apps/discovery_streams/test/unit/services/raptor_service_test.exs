defmodule DiscoveryStreams.Services.RaptorServiceTest do
  use ExUnit.Case
  use Placebo

  alias DiscoveryStreams.Services.RaptorService

  describe "is_authorized/2" do
    test "returns true if authorized in Raptor" do
      allow(HTTPoison.get(any()),
        return: {:ok, %{body: "{\"is_authorized\":true}"}}
      )

      assert RaptorService.is_authorized("ap1K3y", "system__name")
    end

    test "returns false if unauthorized in Raptor" do
      allow(HTTPoison.get(any()),
        return: {:ok, %{body: "{\"is_authorized\":false}"}}
      )

      assert not RaptorService.is_authorized("ap1K3y", "system__name")
    end
  end
end
