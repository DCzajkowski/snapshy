defmodule Snapshy.MixProject do
  use Mix.Project

  def project do
    [
      app: :snapshy,
      version: "0.2.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      #
    ]
  end

  defp description do
    "A testing utility for running snapshot tests"
  end

  defp package do
    [
      maintainers: ["Dariusz Czajkowski"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/dczajkowski/snapshy"}
    ]
  end
end
