defmodule AuthRetrieverTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG

  alias Reaper.Collections.Extractions
  alias Reaper.Cache.AuthCache

  @dataset_id "123"
  @auth_response Jason.encode!(%{"api_key" => "12343523423423"})

  setup do
    Cachex.start(AuthCache.cache_name())
    Cachex.clear(AuthCache.cache_name())

    :ok
  end

  describe "authorize/1" do
    # TODO:  do authorize test things here
  end
end
