%{
  configs: [
    %{
      name: "default",
      ignore: [
        # Add any dependencies to ignore here
        # Example: {:package_name, "reason for ignoring"}
      ],
      only: [
        # Add specific dependencies to check here
        # Example: {:package_name, "reason for checking"}
      ]
    }
  ]
}
