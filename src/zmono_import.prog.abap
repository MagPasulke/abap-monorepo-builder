REPORT zmono_import LINE-SIZE 255.

TABLES sscrfields.

DATA package_name TYPE tdevc-devclass.

SELECT-OPTIONS s_pack FOR package_name OBLIGATORY.
PARAMETERS p_giturl TYPE c LENGTH 255 LOWER CASE VISIBLE LENGTH 60 OBLIGATORY.
PARAMETERS p_logic TYPE c LENGTH 6 AS LISTBOX VISIBLE LENGTH 10 OBLIGATORY.
PARAMETERS p_topfld TYPE c LENGTH 200 LOWER CASE VISIBLE LENGTH 60.

" abapGit login popup (selection screen 1002, FORM password_popup), see technical spec T-020
INCLUDE zabapgit_password_dialog.

CLASS lcl_app DEFINITION FINAL.

  PUBLIC SECTION.
    CLASS-METHODS set_folder_logic_values.
    CLASS-METHODS check_input.
    CLASS-METHODS run.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF colors,
        heading  TYPE i VALUE 1,
        neutral  TYPE i VALUE 2,
        warning  TYPE i VALUE 3,
        positive TYPE i VALUE 5,
        negative TYPE i VALUE 6,
      END OF colors.

    CLASS-METHODS display
      IMPORTING result TYPE REF TO zcl_mono_result.

    CLASS-METHODS display_components
      IMPORTING result TYPE REF TO zcl_mono_result.

    CLASS-METHODS display_summary
      IMPORTING result TYPE REF TO zcl_mono_result.

    CLASS-METHODS get_color
      IMPORTING status        TYPE zif_mono_types=>status
      RETURNING VALUE(result) TYPE i.

ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD set_folder_logic_values.
    DATA(values) = VALUE vrm_values(
      ( key  = zif_abapgit_dot_abapgit=>c_folder_logic-prefix
        text = zif_abapgit_dot_abapgit=>c_folder_logic-prefix )
      ( key  = zif_abapgit_dot_abapgit=>c_folder_logic-full
        text = zif_abapgit_dot_abapgit=>c_folder_logic-full )
      ( key  = zif_abapgit_dot_abapgit=>c_folder_logic-mixed
        text = zif_abapgit_dot_abapgit=>c_folder_logic-mixed ) ).
    CALL FUNCTION 'VRM_SET_VALUES'
      EXPORTING
        id              = 'P_LOGIC'
        values          = values
      EXCEPTIONS
        id_illegal_name = 1
        OTHERS          = 2.
    ASSERT sy-subrc = 0.
  ENDMETHOD.

  METHOD check_input.
    TRY.
        zcl_mono_path_builder=>normalize_top_folder( condense( p_topfld ) ).
        IF p_giturl IS NOT INITIAL.
          zcl_mono_factory=>create_remote_gateway( )->validate_url( condense( p_giturl ) ).
        ENDIF.
      CATCH zcx_mono_error INTO DATA(error).
        MESSAGE error TYPE 'E'.
    ENDTRY.
  ENDMETHOD.

  METHOD run.
    IF sy-batch = abap_true.
      MESSAGE s018(zmono) DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    DATA(parameters) = VALUE zif_mono_types=>run_parameters(
      packages     = s_pack[]
      git_url      = condense( p_giturl )
      folder_logic = p_logic
      top_folder   = condense( p_topfld ) ).
    display( zcl_mono_factory=>create_importer( parameters-git_url )->run( parameters ) ).
  ENDMETHOD.

  METHOD display.
    DATA(run_info) = result->get_run_info( ).
    DATA(default_branch) = zcl_mono_result=>get_short_branch_name( run_info-default_branch ).
    DATA(branch) = zcl_mono_result=>get_short_branch_name( run_info-branch ).

    FORMAT COLOR = colors-heading INTENSIFIED ON.
    WRITE / TEXT-001.
    FORMAT RESET.
    WRITE: / TEXT-002,
           20 run_info-git_url,
           / TEXT-003,
           20 default_branch,
           / TEXT-004,
           20 branch.
    SKIP.

    display_components( result ).
    display_summary( result ).
  ENDMETHOD.

  METHOD display_components.
    DATA component TYPE zif_mono_types=>component_result.
    DATA status_text TYPE string.
    DATA step_text TYPE string.
    DATA merged TYPE string.
    DATA color TYPE i.

    FORMAT COLOR = colors-heading.
    WRITE: /1 TEXT-005,
           33 TEXT-006,
           43 TEXT-007,
           56 TEXT-008.
    FORMAT RESET.

    LOOP AT result->get_components( ) INTO component.
      status_text = CONV string( component-status ).
      step_text = CONV string( component-step ).
      color = get_color( component-status ).
      FORMAT COLOR = color.
      WRITE: /1 component-root_package,
             33 status_text,
             43 step_text,
             56 component-path.
      FORMAT RESET.
      IF component-merged_from IS NOT INITIAL.
        merged = concat_lines_of( table = component-merged_from
                                  sep   = `, ` ).
        WRITE: /5 TEXT-009,
               25 merged.
      ENDIF.
      IF component-reason IS NOT INITIAL.
        WRITE /5 component-reason.
      ENDIF.
    ENDLOOP.
    SKIP.
  ENDMETHOD.

  METHOD display_summary.
    DATA(run_info) = result->get_run_info( ).
    DATA(overall) = result->get_overall_status( ).
    DATA(overall_text) = CONV string( overall ).
    DATA(overall_color) = get_color( overall ).
    DATA(succeeded) = result->count_status( zif_mono_types=>statuses-success ).
    DATA(partial) = result->count_status( zif_mono_types=>statuses-partial ).
    DATA(failed) = result->count_status( zif_mono_types=>statuses-failed ).
    DATA(skipped) = result->count_status( zif_mono_types=>statuses-skipped ).

    FORMAT COLOR = overall_color INTENSIFIED ON.
    WRITE: / TEXT-010,
           20 overall_text.
    FORMAT RESET.
    WRITE: / TEXT-011,
           20 succeeded LEFT-JUSTIFIED,
           / TEXT-012,
           20 partial LEFT-JUSTIFIED,
           / TEXT-013,
           20 failed LEFT-JUSTIFIED,
           / TEXT-014,
           20 skipped LEFT-JUSTIFIED.
    SKIP.

    IF run_info-pr_url IS NOT INITIAL.
      FORMAT COLOR = colors-positive.
      WRITE: / TEXT-015,
             20 run_info-pr_url.
    ENDIF.
    IF run_info-pr_error IS NOT INITIAL.
      FORMAT COLOR = colors-negative.
      WRITE: / TEXT-016,
             / run_info-pr_error,
             / TEXT-017.
    ENDIF.
    IF run_info-pr_hint IS NOT INITIAL.
      FORMAT COLOR = colors-warning.
      WRITE / run_info-pr_hint.
    ENDIF.
    IF run_info-global_error IS NOT INITIAL.
      FORMAT COLOR = colors-negative.
      WRITE: / TEXT-018,
             / run_info-global_error.
    ENDIF.
    FORMAT RESET.
  ENDMETHOD.

  METHOD get_color.
    result = SWITCH #( status
                       WHEN zif_mono_types=>statuses-success THEN colors-positive
                       WHEN zif_mono_types=>statuses-partial THEN colors-warning
                       WHEN zif_mono_types=>statuses-failed THEN colors-negative
                       ELSE colors-neutral ).
  ENDMETHOD.

ENDCLASS.


INITIALIZATION.
  lcl_password_dialog=>on_screen_init( ).
  lcl_app=>set_folder_logic_values( ).

AT SELECTION-SCREEN OUTPUT.
  IF sy-dynnr = lcl_password_dialog=>c_dynnr.
    lcl_password_dialog=>on_screen_output( ).
  ENDIF.

AT SELECTION-SCREEN.
  IF sy-dynnr = lcl_password_dialog=>c_dynnr.
    lcl_password_dialog=>on_screen_event( sscrfields-ucomm ).
  ELSE.
    lcl_app=>check_input( ).
  ENDIF.

START-OF-SELECTION.
  lcl_app=>run( ).
