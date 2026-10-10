Feature: Railway-owned builds for jobs
  Source builds are opt-in and retain the job lifecycle and local resources.

  Scenario Outline: C# finite and cron jobs pass source settings to the shared publisher
    Given a local container and Dockerfile source build settings
    When the container is published as a C# <kind> job
    Then the shared publisher receives the source build settings
    And the local container image is preserved
    And the <kind> job lifecycle is preserved

    Examples:
      | kind   |
      | finite |
      | cron   |

  Scenario Outline: TypeScript finite and cron jobs pass source settings to the shared publisher
    Given a local <resource> and Dockerfile source build settings
    When the resource is published as a TypeScript <kind> job
    Then the shared publisher receives the source build settings
    And the <kind> job lifecycle is preserved

    Examples:
      | resource  | kind   |
      | container | finite |
      | container | cron   |
      | project   | finite |
      | project   | cron   |

  Scenario: Source-built jobs retain deployment prerequisites
    Given a local container and Dockerfile source build settings
    When the source-built job requires an earlier deployment
    Then the shared publisher retains that deployment prerequisite
