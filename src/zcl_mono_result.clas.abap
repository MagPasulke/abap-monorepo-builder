"! Result of an import run
CLASS zcl_mono_result DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Removes the prefix refs/heads/ from a branch name
    CLASS-METHODS get_short_branch_name
      IMPORTING branch        TYPE string
      RETURNING VALUE(result) TYPE string.

    "! Creates an empty result for a Git URL
    METHODS constructor
      IMPORTING git_url TYPE string.

    "! Adds a resolved component with status pending
    METHODS add_component
      IMPORTING component TYPE zif_mono_types=>component.

    "! Records the step a component has reached
    METHODS set_step
      IMPORTING root_package TYPE devclass
                step         TYPE zif_mono_types=>step.

    "! Completes a component with a final status and reason
    METHODS complete
      IMPORTING root_package TYPE devclass
                status       TYPE zif_mono_types=>status
                reason       TYPE string.

    "! Records the outcome of a push and completes the component
    METHODS set_push_result
      IMPORTING root_package TYPE devclass
                push_result  TYPE zif_mono_types=>push_result.

    "! Marks all pending components as skipped
    METHODS skip_pending
      IMPORTING reason TYPE string.

    "! Returns the status of a component
    METHODS get_status
      IMPORTING root_package  TYPE devclass
      RETURNING VALUE(result) TYPE zif_mono_types=>status.

    "! Returns the number of components with a status
    METHODS count_status
      IMPORTING wanted_status TYPE zif_mono_types=>status
      RETURNING VALUE(result) TYPE i.

    "! Returns true if at least one component was pushed with changes
    METHODS has_pushed_components
      RETURNING VALUE(result) TYPE abap_bool.

    "! Returns all component results
    METHODS get_components
      RETURNING VALUE(result) TYPE zif_mono_types=>component_results.

    "! Returns branch, pull request and error information of the run
    METHODS get_run_info
      RETURNING VALUE(result) TYPE zif_mono_types=>run_info.

    "! Sets the working branch
    METHODS set_branch
      IMPORTING branch TYPE string.

    "! Sets the default branch of the remote
    METHODS set_default_branch
      IMPORTING branch TYPE string.

    "! Sets the URL of the created pull request
    METHODS set_pr_url
      IMPORTING url TYPE string.

    "! Sets the error of the pull request creation
    METHODS set_pr_error
      IMPORTING error TYPE string.

    "! Sets a hint why no pull request was created
    METHODS set_pr_hint
      IMPORTING hint TYPE string.

    "! Sets the error that stopped the run
    METHODS set_global_error
      IMPORTING error TYPE string.

    "! Returns the overall status of the run
    METHODS get_overall_status
      RETURNING VALUE(result) TYPE zif_mono_types=>status.

    "! Returns the pull request title
    METHODS build_pr_title
      RETURNING VALUE(result) TYPE string.

    "! Returns the pull request description in Markdown
    METHODS build_pr_body
      RETURNING VALUE(result) TYPE string.

  PRIVATE SECTION.
    DATA components TYPE zif_mono_types=>component_results.
    DATA run_info TYPE zif_mono_types=>run_info.

    CLASS-METHODS escape_markdown
      IMPORTING text          TYPE string
      RETURNING VALUE(result) TYPE string.

    METHODS get_entry
      IMPORTING root_package  TYPE devclass
      RETURNING VALUE(result) TYPE REF TO zif_mono_types=>component_result.

    METHODS count_pushed
      RETURNING VALUE(result) TYPE i.

    METHODS build_section
      IMPORTING title         TYPE string
                wanted_status TYPE zif_mono_types=>status
      RETURNING VALUE(result) TYPE string.

    CLASS-METHODS build_row
      IMPORTING entry         TYPE zif_mono_types=>component_result
      RETURNING VALUE(result) TYPE string.

ENDCLASS.


CLASS zcl_mono_result IMPLEMENTATION.

  METHOD get_short_branch_name.
    result = replace( val  = branch
                      pcre = `^refs/heads/`
                      with = `` ).
  ENDMETHOD.

  METHOD constructor.
    run_info-git_url = git_url.
  ENDMETHOD.

  METHOD add_component.
    INSERT VALUE #( root_package = component-root_package
                    path         = component-path
                    merged_from  = component-merged_from ) INTO TABLE components.
  ENDMETHOD.

  METHOD set_step.
    DATA(entry) = get_entry( root_package ).
    entry->step = step.
  ENDMETHOD.

  METHOD complete.
    DATA(entry) = get_entry( root_package ).
    entry->status = status.
    entry->reason = reason.
  ENDMETHOD.

  METHOD set_push_result.
    DATA reasons TYPE string_table.
    DATA text TYPE string.

    DATA(entry) = get_entry( root_package ).
    entry->remote_only_files = push_result-remote_only_files.
    entry->warnings = push_result-warnings.
    entry->step = COND #( WHEN push_result-changed = abap_true
                          THEN zif_mono_types=>steps-pushed
                          ELSE zif_mono_types=>steps-no_changes ).
    entry->status = COND #( WHEN push_result-warnings > 0
                            THEN zif_mono_types=>statuses-partial
                            ELSE zif_mono_types=>statuses-success ).

    IF push_result-changed = abap_false.
      MESSAGE i032(zmono) INTO text.
      INSERT text INTO TABLE reasons.
    ENDIF.
    IF push_result-warnings > 0.
      MESSAGE i031(zmono) WITH push_result-warnings push_result-warning_text INTO text.
      INSERT text INTO TABLE reasons.
    ENDIF.
    IF push_result-remote_only_files > 0.
      MESSAGE i030(zmono) WITH push_result-remote_only_files INTO text.
      INSERT text INTO TABLE reasons.
    ENDIF.
    entry->reason = concat_lines_of( table = reasons
                                     sep   = `; ` ).
  ENDMETHOD.

  METHOD skip_pending.
    DATA entry TYPE REF TO zif_mono_types=>component_result.

    LOOP AT components REFERENCE INTO entry WHERE status = zif_mono_types=>statuses-pending.
      entry->status = zif_mono_types=>statuses-skipped.
      entry->reason = reason.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_status.
    result = get_entry( root_package )->status.
  ENDMETHOD.

  METHOD count_status.
    result = REDUCE #( INIT count = 0
                       FOR entry IN components WHERE ( status = wanted_status )
                       NEXT count = count + 1 ).
  ENDMETHOD.

  METHOD has_pushed_components.
    result = xsdbool( line_exists( components[ step = zif_mono_types=>steps-pushed ] ) ).
  ENDMETHOD.

  METHOD get_components.
    result = components.
  ENDMETHOD.

  METHOD get_run_info.
    result = run_info.
  ENDMETHOD.

  METHOD set_branch.
    run_info-branch = branch.
  ENDMETHOD.

  METHOD set_default_branch.
    run_info-default_branch = branch.
  ENDMETHOD.

  METHOD set_pr_url.
    run_info-pr_url = url.
  ENDMETHOD.

  METHOD set_pr_error.
    run_info-pr_error = error.
  ENDMETHOD.

  METHOD set_pr_hint.
    run_info-pr_hint = hint.
  ENDMETHOD.

  METHOD set_global_error.
    run_info-global_error = error.
  ENDMETHOD.

  METHOD get_overall_status.
    DATA(succeeded) = count_status( zif_mono_types=>statuses-success ).
    DATA(partially_succeeded) = count_status( zif_mono_types=>statuses-partial ).
    DATA(all_succeeded) = xsdbool( lines( components ) = succeeded ).
    DATA(pr_missing) = xsdbool( has_pushed_components( ) = abap_true AND run_info-pr_url IS INITIAL ).

    IF run_info-global_error IS NOT INITIAL OR succeeded + partially_succeeded = 0.
      result = zif_mono_types=>statuses-failed.
    ELSEIF all_succeeded = abap_true AND pr_missing = abap_false.
      result = zif_mono_types=>statuses-success.
    ELSE.
      result = zif_mono_types=>statuses-partial.
    ENDIF.
  ENDMETHOD.

  METHOD build_pr_title.
    result = |ABAP import: { count_pushed( ) } component(s) ({ get_short_branch_name( run_info-branch ) })|.
  ENDMETHOD.

  METHOD build_pr_body.
    result = |Automated import of ABAP packages via report ZMONO_IMPORT.\n\n|
          && |Branch: { get_short_branch_name( run_info-branch ) }\n\n|
          && build_section( title         = `Imported`
                            wanted_status = zif_mono_types=>statuses-success )
          && build_section( title         = `Partially imported`
                            wanted_status = zif_mono_types=>statuses-partial )
          && build_section( title         = `Failed`
                            wanted_status = zif_mono_types=>statuses-failed )
          && build_section( title         = `Skipped`
                            wanted_status = zif_mono_types=>statuses-skipped ).
  ENDMETHOD.

  METHOD escape_markdown.
    result = replace( val  = text
                      sub  = `|`
                      with = `\|`
                      occ  = 0 ).
    result = replace( val  = result
                      sub  = |\n|
                      with = ` `
                      occ  = 0 ).
  ENDMETHOD.

  METHOD get_entry.
    result = REF #( components[ root_package = root_package ] ).
  ENDMETHOD.

  METHOD count_pushed.
    result = REDUCE #( INIT count = 0
                       FOR entry IN components WHERE ( step = zif_mono_types=>steps-pushed )
                       NEXT count = count + 1 ).
  ENDMETHOD.

  METHOD build_section.
    DATA(rows) = VALUE string_table( FOR entry IN components WHERE ( status = wanted_status )
                                     ( build_row( entry ) ) ).
    IF rows IS INITIAL.
      RETURN.
    ENDIF.

    result = |### { title } ({ lines( rows ) })\n\n|
          && |\| Package \| Path \| Details \|\n|
          && |\|---\|---\|---\|\n|
          && concat_lines_of( table = rows
                              sep   = |\n| )
          && |\n\n|.
  ENDMETHOD.

  METHOD build_row.
    result = |\| { entry-root_package } \| { escape_markdown( entry-path ) } \| { escape_markdown( entry-reason ) } \||.
  ENDMETHOD.

ENDCLASS.

