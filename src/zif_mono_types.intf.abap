"! Types shared by the monorepo import
INTERFACE zif_mono_types PUBLIC.

  TYPES ty_package_names TYPE STANDARD TABLE OF devclass WITH EMPTY KEY.
  TYPES ty_package_range TYPE RANGE OF devclass.
  TYPES ty_repo_key TYPE c LENGTH 12.

  TYPES:
    BEGIN OF ENUM ty_step STRUCTURE steps,
      resolved,
      checked,
      created,
      configured,
      online,
      branch_selected,
      pushed,
      unchanged,
    END OF ENUM ty_step STRUCTURE steps.

  TYPES:
    BEGIN OF ENUM ty_status STRUCTURE statuses,
      pending,
      success,
      partial,
      failed,
      skipped,
    END OF ENUM ty_status STRUCTURE statuses.

  TYPES:
    BEGIN OF ty_component,
      root_package    TYPE devclass,
      name            TYPE string,
      path            TYPE string,
      starting_folder TYPE string,
      sub_packages    TYPE ty_package_names,
      merged_from     TYPE ty_package_names,
    END OF ty_component.
  TYPES ty_components TYPE STANDARD TABLE OF ty_component WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_run_parameters,
      packages     TYPE ty_package_range,
      git_url      TYPE string,
      folder_logic TYPE string,
      top_folder   TYPE string,
    END OF ty_run_parameters.

  TYPES:
    BEGIN OF ty_component_result,
      root_package      TYPE devclass,
      path              TYPE string,
      step              TYPE ty_step,
      status            TYPE ty_status,
      reason            TYPE string,
      merged_from       TYPE ty_package_names,
      remote_only_files TYPE i,
      warnings          TYPE i,
    END OF ty_component_result.
  TYPES ty_component_results TYPE STANDARD TABLE OF ty_component_result WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_push_result,
      changed           TYPE abap_bool,
      remote_only_files TYPE i,
      warnings          TYPE i,
      warning_text      TYPE string,
    END OF ty_push_result.

  TYPES:
    BEGIN OF ty_run_info,
      git_url            TYPE string,
      branch             TYPE string,
      default_branch     TYPE string,
      pull_request_url   TYPE string,
      pull_request_error TYPE string,
      pull_request_hint  TYPE string,
      global_error       TYPE string,
    END OF ty_run_info.

  TYPES:
    BEGIN OF ty_repo_assignment,
      name         TYPE string,
      package_name TYPE devclass,
      sub_packages TYPE ty_package_names,
    END OF ty_repo_assignment.
  TYPES ty_repo_assignments TYPE STANDARD TABLE OF ty_repo_assignment WITH EMPTY KEY.

  CONSTANTS repo_label TYPE string VALUE `monorepo`.
  CONSTANTS branch_prefix TYPE string VALUE `refs/heads/`.

ENDINTERFACE.
