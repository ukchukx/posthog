defmodule Posthog.MixProject do
  use Mix.Project

  def project do
    [
      app: :posthog,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package()
    ]
  end

  def application do
    [
      env: [
        api_url: "https://eu.posthog.com",
        api_key: "phx_iFLtZhbIGLkMpU0BqLCEuix8pHrCwv1IUOQZxZwdhFj"
      ]
    ]
  end

  defp description do
    """
    Elixir HTTP client for Posthog.
    """
  end

  defp package do
    [
      name: :posthog,
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Nick Kezhaya"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/whitepaperclip/posthog"}
    ]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0"},
      {:jason, "~> 1.4"},
      {:req, "~> 0.4.0"},
      {:uuid, "~> 1.1"}
    ]
  end
end
