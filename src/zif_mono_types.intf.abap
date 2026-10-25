"! Types shared by the monorepo import
INTERFACE zif_mono_types PUBLIC.

  TYPES package_names TYPE STANDARD TABLE OF devclass WITH EMPTY KEY.
  TYPES package_range TYPE RANGE OF devclass.
  TYPES repo_key TYPE c LENGTH 12.

  TYPES:
    BEGIN OF ENUM step STRUCTURE steps,
      resolved,
      checked,
      created,
      configured,
      online,
      on_branch,
      pushed,
      no_changes,
    END OF ENUM step STRUCTURE steps.

  TYPES:
    BEGIN OF ENUM status STRUCTURE statuses,
      pending,
      success,
      partial,
      failed,
      skipped,
    END OF ENUM status STRUCTURE statuses.

  TYPES:
    BEGIN OF component,
      root_package    TYPE devclass,
      name            TYPE string,
      path            TYPE string,
      starting_folder TYPE string,
      sub_packages    TYPE package_names,
      merged_from     TYPE package_names,
    END OF component.
  TYPES components TYPE STANDARD TABLE OF component WITH EMPTY KEY.

  TYPES:
    BEGIN OF run_parameters,
      packages     TYPE package_range,
      git_url      TYPE string,
      folder_logic TYPE string,
      top_folder   TYPE string,
    END OF run_parameters.

  TYPES:
    BEGIN OF component_result,
      root_package      TYPE devclass,
      path              TYPE string,
      step              TYPE step,
      status            TYPE status,
      reason            TYPE string,
      merged_from       TYPE package_names,
      remote_only_files TYPE i,
      warnings          TYPE i,
    END OF component_result.
  TYPES component_results TYPE STANDARD TABLE OF component_result WITH EMPTY KEY.

  TYPES:
    BEGIN OF push_result,
      changed           TYPE abap_bool,
      remote_only_files TYPE i,
      warnings          TYPE i,
      warning_text      TYPE string,
    END OF push_result.

  TYPES:
    BEGIN OF run_info,
      git_url        TYPE string,
      branch         TYPE string,
      default_branch TYPE string,
      pr_url         TYPE string,
      pr_error       TYPE string,
      pr_hint        TYPE string,
      global_error   TYPE string,
    END OF run_info.

  TYPES:
    BEGIN OF repo_assignment,
      name         TYPE string,
      package_name TYPE devclass,
      sub_packages TYPE package_names,
    END OF repo_assignment.
  TYPES repo_assignments TYPE STANDARD TABLE OF repo_assignment WITH EMPTY KEY.

  CONSTANTS repo_label TYPE string VALUE `monorepo`.
  CONSTANTS branch_prefix TYPE string VALUE `refs/heads/`.

ENDINTERFACE.
