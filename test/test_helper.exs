Mimic.copy(:hackney)

{:ok, _} = Registry.start_link(keys: :unique, name: :hackney_stub_registry)
{:ok, _} = HackneyStub.State.start_link([])

ExUnit.start()
