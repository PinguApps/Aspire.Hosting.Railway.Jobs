Feature: Railway package dependency binding
  Jobs must run with the same core assembly identity that consumers restore.

  Scenario: The built Jobs publisher references the installed core assembly version
    Given the built Jobs publisher and installed Railway core dependency
    When the publisher assembly dependencies are inspected
    Then the Railway reference matches the installed core assembly version
