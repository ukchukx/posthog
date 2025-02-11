defmodule Posthog.MixProject do
  use Mix.Project

  def project do
    [
      app: :posthog,
      version: "0.4.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package()
    ]
  end

  def application do
    []
  end

  defp description do
    """
    Official PostHog Elixir HTTP client.
    """
  end

  defp package do
    [
      name: :posthog,
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["PostHog"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/posthog/posthog-elixir"}
    ]
  end

  defp deps do
    [
      {:hackney, "~> 1.20"},
      {:jason, "~> 1.4", optional: true},
      {:ex_doc, ">= 0.0.0", only: [:doc]},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false}
    ]
  end
end
