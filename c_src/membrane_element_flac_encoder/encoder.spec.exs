module Membrane.Element.FLAC.Encoder.Native

spec create(
       pid :: pid,
       sample_rate :: unsigned,
       sample_size :: unsigned,
       channels :: unsigned,
       compression_level :: int,
       verify :: bool
     ) ::
       {:ok :: label, state} | {:error :: label, reason :: atom}

spec encode(payload, state) ::
       (:ok :: label) | {:error :: label, reason :: atom}

spec flush(state) :: (:ok :: label) | {:error :: label, reason :: atom}

dirty :cpu, encode: 3, flush: 1

sends {:encoded :: label, payload}
