# ProtocolDecoder

Defines a protocol for decoding data (based on format) as it's ingested.

## Usage

A decoder must implement two functions to allow decoding via this protocol:
`lines_or_bytes/1` and `decode/2`.

See [Decover.Csv](../decoder_csv/lib/decoder/csv.ex) as an example.

## Installation

```elixir
def deps do
  [
    {:protocol_decoder, in_umbrella: true}
  ]
end
```
