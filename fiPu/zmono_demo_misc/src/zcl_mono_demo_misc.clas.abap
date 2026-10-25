"! Monorepo demo: misc
CLASS zcl_mono_demo_misc DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Returns true for even numbers
    METHODS is_even
      IMPORTING number        TYPE i
      RETURNING VALUE(result) TYPE abap_bool.
ENDCLASS.


CLASS zcl_mono_demo_misc IMPLEMENTATION.

  METHOD is_even.
    result = xsdbool( number MOD 2 = 0 ).
  ENDMETHOD.

ENDCLASS.

