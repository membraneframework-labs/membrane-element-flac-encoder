defmodule Membrane.Element.FLAC.Encoder.Mixfile do
  use Mix.Project

  @version "0.1.0"
  @github_url "https://github.com/membraneframework/membrane-element-flac-encoder"

  def project do
    [
      app: :membrane_element_flac_encoder,
      compilers: [:unifex, :bundlex] ++ Mix.compilers(),
      version: @version,
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "Membrane Multimedia Framework - FLAC Encoder Element",
      package: package(),
      name: "Membrane Element: FLAC Encoder",
      source_url: @github_url,
      docs: docs(),
      preferred_cli_env: [espec: :test, format: :test],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [],
      mod: {Membrane.Element.FLAC.Encoder.App, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}",
      nest_modules_by_prefix: [Membrane.Element.FLAC.Encoder]
    ]
  end

  defp package do
    [
      maintainers: ["Membrane Team"],
      licenses: ["Apache 2.0"],
      files: ["c_src", "lib", "mix.exs", "README*", "LICENSE*", ".formatter.exs", "bundlex.exs"],
      links: %{
        "GitHub" => @github_url,
        "Membrane Framework Homepage" => "https://membraneframework.org"
      }
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:membrane_core, "~> 0.4.1"},
      {:membrane_caps_audio_raw, "~> 0.1.0"},
      {:membrane_caps_audio_flac, "~> 0.1.1"},
      {:membrane_common_c, "~> 0.2.0"},
      {:bundlex, "~> 0.2.0"},
      {:bunch, "~> 1.0"},
      {:unifex, "~> 0.2.0"},
      {:membrane_element_file, "~> 0.2.2", only: :test},
      {:membrane_element_ffmpeg_swresample, "~> 0.2.5", only: :test}
    ]
  end
end
