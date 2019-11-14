defmodule FLAC.Encoder.IntegrationTest do
  use ExUnit.Case
  import Membrane.Testing.Assertions
  alias Membrane.Testing.Pipeline
  alias Membrane.Element

  test "Encode raw samples" do
    in_path = "test/fixtures/input.pcm"
    out_path = "/tmp/output-flac.flac"
    ref_path = "/tmp/input-flac-ref.pcm"

    on_exit(fn ->
      File.rm(out_path)
      File.rm(ref_path)
    end)

    caps = %Membrane.Caps.Audio.Raw{
      format: :s16le,
      sample_rate: 44100,
      channels: 2
    }

    assert {:ok, pid} =
             Pipeline.start_link(%Pipeline.Options{
               elements: [
                 file_src: %Element.File.Source{chunk_size: 4096, location: in_path},
                 converter: %Membrane.Element.FFmpeg.SWResample.Converter{
                   input_caps: caps,
                   output_caps: caps
                 },
                 encoder: Element.FLAC.Encoder,
                 sink: %Element.File.Sink{location: out_path}
               ]
             })

    assert Pipeline.play(pid) == :ok
    assert_end_of_stream(pid, :sink, :input, 1000)

    System.cmd("bash", [
      "-c",
      "ffmpeg -hide_banner -loglevel panic  -i #{out_path} -f s16le -acodec pcm_s16le #{ref_path}"
    ])

    assert {:ok, in_file} = File.read(in_path)
    assert {:ok, ref_file} = File.read(ref_path)
    assert in_file == ref_file
  end
end
