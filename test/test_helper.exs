Mimic.copy(:hackney)

{:ok, _} = HackneyStub.State.start_link([])

ExUnit.start()
