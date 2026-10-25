"! Monorepo demo: text utility
CLASS zcl_mono_demo_app_util DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Returns the text with the first letter in upper case
    METHODS to_title
      IMPORTING text          TYPE string
      RETURNING VALUE(result) TYPE string.
ENDCLASS.


CLASS zcl_mono_demo_app_util IMPLEMENTATION.

  METHOD to_title.
    result = to_upper( substring( val = text
                                  len = 1 ) ) && to_lower( substring( val = text
                                                                      off = 1 ) ).
  ENDMETHOD.

ENDCLASS.

