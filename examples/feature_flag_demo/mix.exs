defmodule FeatureFlagDemo.MixProject do
  use Mix.Project

  def project do
    [
      app: :feature_flag_demo,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :posthog]
    ]
  end

  defp deps do
    [
      {:posthog, path: "../.."},
      {:jason, "~> 1.4"}
    ]
  end
end
