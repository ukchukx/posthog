defmodule HackneyStub.Base do
  @fixtures_dir Path.join(__DIR__, "fixtures")

  defmacro __using__(fixture) do
    quote do
      @fixtures_dir unquote(@fixtures_dir)

      def post("https://us.posthog.com/decide?v=3", _headers, _body, _opts) do
        {:ok, 200, json_fixture!(unquote(fixture)), "decide"}
      end

      def body("decide") do
        {:ok, json_fixture!(unquote(fixture))}
      end

      defp json_fixture!(fixture) do
        @fixtures_dir
        |> Path.join(fixture)
        |> File.read!()
      end
    end
  end
end

defmodule HackneyStub do
  use HackneyStub.Base, "decide.json"
end

defmodule HackneyStubV3 do
  use HackneyStub.Base, "decide-v3.json"
end
