defmodule Membrane.Element.FLAC.Encoder do
  @moduledoc """
  Element encoding raw audio into MPEG-1, layer 3 format
  """
  use Membrane.Filter
  alias Membrane.Caps.Audio.{FLAC, Raw}
  alias Membrane.Buffer
  alias __MODULE__.Native

  use Membrane.Log, tags: :membrane_element_flac_encoder

  @estimated_frame_size 1152

  @estimated_compression_ratio 2

  def_output_pad :output, caps: FLAC

  def_input_pad :input,
    demand_unit: :bytes,
    caps: {Raw, format: one_of([:s8, :s16le, :s24le]), sample_rate: range(0, 48_000)}

  @impl true
  def handle_init(_options) do
    {:ok, %{native: nil, queue: <<>>}}
  end

  @impl true
  def handle_demand(:output, size, :bytes, _ctx, state) do
    {{:ok, demand: {:input, size * @estimated_compression_ratio}}, state}
  end

  @impl true
  def handle_demand(:output, _size, :buffers, %{pads: %{input: %{caps: nil}}}, state) do
    {:ok, state}
  end

  @impl true
  def handle_demand(:output, bufs, :buffers, ctx, state) do
    {{:ok,
      demand: {:input, Raw.frames_to_bytes(@estimated_frame_size, ctx.pads.input.caps) * bufs}},
     state}
  end

  @impl true
  def handle_caps(:input, caps, _ctx, state) do
    %Raw{channels: channels, sample_rate: sample_rate} = caps

    caps = %FLAC{
      channels: channels,
      sample_rate: sample_rate,
      sample_size: Raw.sample_size(caps) * 8
    }

    {{:ok, caps: {:output, caps}, redemand: :output}, state}
  end

  @impl true
  def handle_start_of_stream(:input, ctx, state) do
    %{caps: caps} = ctx.pads.output

    case Native.create(self(), caps.sample_rate, caps.sample_size, caps.channels, 5, false) do
      {:ok, native} -> {:ok, %{state | native: native}}
      error -> {error, state}
    end
  end

  @impl true
  def handle_end_of_stream(:input, _ctx, state) do
    case Native.flush(state.native) do
      :ok ->
        send(self(), :flushed)
        {:ok, state}

      error ->
        {error, state}
    end
  end

  @impl true
  def handle_process(:input, %Buffer{payload: payload}, ctx, state) do
    %{native: native, queue: queue} = state
    %{caps: caps} = ctx.pads.input
    queue = queue <> payload
    {payload, queue} = Bunch.Binary.split_int_part(queue, Raw.frame_size(caps))
    encode_res = Native.encode(payload, native)
    {encode_res, %{state | queue: queue}}
  end

  @impl true
  def handle_other({:encoded, payload}, %{playback_state: :playing}, state) do
    {{:ok, buffer: {:output, %Buffer{payload: payload}}, redemand: :output}, state}
  end

  @impl true
  def handle_other({:encoded, _payload}, _ctx, state) do
    {:ok, state}
  end

  @impl true
  def handle_other(:flushed, _ctx, state) do
    {{:ok, end_of_stream: :output}, state}
  end
end
