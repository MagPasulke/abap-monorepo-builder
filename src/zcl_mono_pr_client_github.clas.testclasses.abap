CLASS ltcl_pr_client_github DEFINITION DEFERRED.
CLASS zcl_mono_pr_client_github DEFINITION LOCAL FRIENDS ltcl_pr_client_github.

CLASS ltcl_pr_client_github DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS owner_and_repo_with_git FOR TESTING.
    METHODS owner_and_repo_without_git FOR TESTING.
    METHODS other_provider FOR TESTING.
    METHODS payload_escaped FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltcl_pr_client_github IMPLEMENTATION.

  METHOD owner_and_repo_with_git.
    cl_abap_unit_assert=>assert_equals(
      exp = `acme/mono`
      act = zcl_mono_pr_client_github=>get_owner_and_repo( `https://github.com/acme/mono.git` ) ).
  ENDMETHOD.

  METHOD owner_and_repo_without_git.
    cl_abap_unit_assert=>assert_equals(
      exp = `acme/mono`
      act = zcl_mono_pr_client_github=>get_owner_and_repo( `https://github.com/acme/mono/` ) ).
  ENDMETHOD.

  METHOD other_provider.
    cl_abap_unit_assert=>assert_initial(
      zcl_mono_pr_client_github=>get_owner_and_repo( `https://gitlab.com/acme/mono.git` ) ).
  ENDMETHOD.

  METHOD payload_escaped.
    DATA(cut) = NEW zcl_mono_pr_client_github( `https://github.com/acme/mono.git` ).

    DATA(payload) = cut->build_payload( title = `Say "hi"`
                                        body  = |line 1\nline 2|
                                        head  = `abap-import/1`
                                        base  = `main` ).

    cl_abap_unit_assert=>assert_true( xsdbool( payload CS `"title":"Say \"hi\""` ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( payload CS `"body":"line 1\nline 2"` ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( payload CS `"draft":false` ) ).
  ENDMETHOD.

ENDCLASS.
