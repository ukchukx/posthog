defmodule HackneyStubV3 do
  @fixtures_dir Path.join(__DIR__, "fixtures")

  def post("https://us.posthog.com/decide?v=3", _headers, _body, _opts) do
    {:ok, 200, json_fixture!("decide.json"), "decide"}
  end

  def body("decide") do
    {:ok, json_fixture!("decide.json")}
  end

  defp json_fixture!(fixture) do
    @fixtures_dir
    |> Path.join(fixture)
    |> File.read!()
  end
end

defmodule HackneyStub do
  @fixtures_dir Path.join(__DIR__, "fixtures")

  def post("https://us.posthog.com/decide?v=3", _headers, _body, _opts) do
    {:ok, 200, json_fixture!("decide-v3.json"), "decide"}
  end

  def body("decide") do
    {:ok, json_fixture!("decide-v3.json")}
  end

  defp json_fixture!(fixture) do
    @fixtures_dir
    |> Path.join(fixture)
    |> File.read!()
  end
end
