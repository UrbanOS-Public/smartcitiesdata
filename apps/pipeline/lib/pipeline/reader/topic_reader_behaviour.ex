defmodule Pipeline.Reader.TopicReader.Behaviour do
  @callback init(any) :: any
  @callback terminate(any) :: any
end
