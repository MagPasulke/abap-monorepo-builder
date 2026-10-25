"! Base class for errors of the monorepo import
CLASS zcx_mono_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  ABSTRACT
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_t100_dyn_msg.

    "! Creates the exception
    METHODS constructor
      IMPORTING textid   LIKE if_t100_message=>t100key OPTIONAL
                previous LIKE previous OPTIONAL.

    "! Returns the message text followed by the texts of all previous exceptions
    METHODS get_full_text
      RETURNING VALUE(result) TYPE string.

ENDCLASS.


CLASS zcx_mono_error IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = if_t100_message=>default_textid.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
  ENDMETHOD.

  METHOD get_full_text.
    result = get_text( ).
    DATA(cause) = previous.
    WHILE cause IS BOUND.
      result = |{ result }: { cause->get_text( ) }|.
      cause = cause->previous.
    ENDWHILE.
  ENDMETHOD.

ENDCLASS.

