defmodule Reaper.Collections.FileIngestions do
  @moduledoc false

  @instance_name Reaper.instance_name()

  use Reaper.Collections.BaseIngestion, instance: @instance_name, collection: :file_ingestions
end
