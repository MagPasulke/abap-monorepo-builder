"! Monorepo demo: foreign naming
CLASS zcl_mono_demo_foreign DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Returns the text reversed
    METHODS reverse
      IMPORTING text          TYPE string
      RETURNING VALUE(result) TYPE string.
ENDCLASS.


CLASS zcl_mono_demo_foreign IMPLEMENTATION.

  METHOD reverse.
    result = reverse( text ).
  ENDMETHOD.

ENDCLASS.

