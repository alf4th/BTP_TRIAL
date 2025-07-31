CLASS lhc_zr_rap_100_travel DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS : BEGIN OF travel_status,
                  open     TYPE c LENGTH 1 VALUE 'O',
                  accepted TYPE c LENGTH 1 VALUE 'A',
                  rejected TYPE c LENGTH 1 VALUE 'X',
                END OF travel_status.
    METHODS:
      get_global_authorizations FOR GLOBAL AUTHORIZATION
        IMPORTING
        REQUEST requested_authorizations FOR Travel
        RESULT result,
      earlynumbering_create FOR NUMBERING
        IMPORTING entities FOR CREATE Travel,
      setStatusOpen FOR DETERMINE ON MODIFY
        IMPORTING keys FOR Travel~setStatusOpen,
      validateCustomer FOR VALIDATE ON SAVE
        IMPORTING keys FOR Travel~validateCustomer.

    METHODS validateDates FOR VALIDATE ON SAVE
      IMPORTING keys FOR Travel~validateDates.
    METHODS deductDiscount FOR MODIFY
      IMPORTING keys FOR ACTION Travel~deductDiscount RESULT result.
    METHODS copyTravel FOR MODIFY
      IMPORTING keys FOR ACTION Travel~copyTravel.
    METHODS acceptTravel FOR MODIFY
      IMPORTING keys FOR ACTION Travel~acceptTravel RESULT result.

    METHODS rejectTravel FOR MODIFY
      IMPORTING keys FOR ACTION Travel~rejectTravel RESULT result.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Travel RESULT result.
ENDCLASS.

CLASS lhc_zr_rap_100_travel IMPLEMENTATION.
  METHOD get_global_authorizations.
  ENDMETHOD.
  METHOD earlynumbering_create.
    DATA : entity           TYPE STRUCTURE FOR CREATE zr_rap_100_travel,
           travel_id_max    TYPE /dmo/travel_id,
           "Change to abap_false if you get the ABAP Runtime error BEHAVIOUR_ILLEGAL_STATEMENT
           use_number_range TYPE abap_bool VALUE abap_true.

    "Ensure Travel ID is not set yet - must be checked when BO is draft-enabled
    LOOP AT entities INTO entity WHERE TravelId IS NOT INITIAL.
      APPEND CORRESPONDING #( entity ) TO mapped-travel.
    ENDLOOP.

    DATA(entities_wo_travelid) = entities.
    "Remove the entries with an existing Travel ID
    DELETE entities_wo_travelid WHERE TravelId IS NOT INITIAL.

    IF use_number_range EQ abap_true.
      "Get Numbers
      TRY.
          cl_numberrange_runtime=>number_get(
            EXPORTING
*                ignore_buffer     =
              nr_range_nr       = '01'
              object            = '/DMO/TRV_M'
              quantity          = CONV #( lines( entities_wo_travelid ) )
            IMPORTING
              number            = DATA(number_range_key)
              returncode        = DATA(number_range_return_code)
              returned_quantity = DATA(number_range_returned_qty)
          ).
*            CATCH cx_nr_object_not_found.
        CATCH cx_number_ranges INTO DATA(lx_number_ranges).
          LOOP AT entities_wo_travelid INTO entity.
            APPEND VALUE #(  %cid      = entity-%cid
                 %key      = entity-%key
                 %is_draft = entity-%is_draft
                 %msg      = lx_number_ranges
              ) TO reported-travel.
            APPEND VALUE #(  %cid      = entity-%cid
                             %key      = entity-%key
                             %is_draft = entity-%is_draft
                          ) TO failed-travel.
          ENDLOOP.
          EXIT.
      ENDTRY.
      "determine the first free travel ID from the number range
      "subtract untuk adjust length dari number range agar sesuai dengan length dari travel id
      travel_id_max = number_range_key - number_range_returned_qty.
    ELSE.
      "determine the first free travel ID without number range
      "Get max travel ID from active table
      SELECT SINGLE FROM zrap_100_travel FIELDS MAX( travel_id ) AS travelID INTO @travel_id_max.
      "Get max travel ID from draft table
      SELECT SINGLE FROM zrap_100_trvel_d FIELDS MAX( travelid ) INTO @DATA(max_travelid_draft).
      IF max_travelid_draft > travel_id_max.
        travel_id_max = max_travelid_draft.
      ENDIF.
    ENDIF.

    "Set Travel ID for new instances w/o ID
    LOOP AT entities_wo_travelid INTO entity.
      travel_id_max += 1.
      entity-TravelID = travel_id_max.

      APPEND VALUE #( %cid      = entity-%cid
                      %key      = entity-%key
                      %is_draft = entity-%is_draft
                    ) TO mapped-travel.
    ENDLOOP.
  ENDMETHOD.

  METHOD setStatusOpen.
    "Read Travel instance of the transferred keys
    READ ENTITIES OF zr_rap_100_travel IN LOCAL MODE
     ENTITY travel FIELDS ( OverallStatus )
     WITH CORRESPONDING #( keys )
     RESULT DATA(travels)
     FAILED DATA(read_failed).

    "if overall travel status is already set, do nothing
    DELETE travels WHERE OverallStatus IS NOT INITIAL.
    CHECK travels IS NOT INITIAL.

    "else set overall travel status to open ('O')
    MODIFY ENTITIES OF zr_rap_100_travel IN LOCAL MODE
    ENTITY travel
    UPDATE FIELDS ( OverallStatus )
    WITH VALUE #( FOR travel IN travels ( %tky = travel-%tky
                                          OverallStatus = travel_status-open ) )
    REPORTED DATA(update_reported).

    "set changing parameter
    reported = CORRESPONDING #( DEEP update_reported ).
  ENDMETHOD.

  METHOD validateCustomer.

    DATA customers TYPE SORTED TABLE OF /dmo/customer WITH UNIQUE KEY customer_id.

    "read relevant travel instance data
    READ ENTITIES OF zr_rap_100_travel IN LOCAL MODE
     ENTITY travel
     FIELDS ( CustomerId )
     WITH CORRESPONDING #( keys )
     RESULT DATA(travels).

    "optimization of DB select: extract distinct non-initial customer IDs
    customers = CORRESPONDING #( travels DISCARDING DUPLICATES MAPPING customer_id = CustomerId EXCEPT * ).
    DELETE customers WHERE customer_id IS INITIAL.

    IF customers IS NOT INITIAL.
      "check if customer ID exist
      SELECT FROM /dmo/customer FIELDS customer_id
      FOR ALL ENTRIES IN @customers
      WHERE customer_id = @customers-customer_id
      INTO TABLE @DATA(valid_customers).
    ENDIF.

    "raise message for non existing and initial customer id
    LOOP AT travels INTO DATA(travel_s).
      APPEND VALUE #( %tky        = travel_s-%tky
                      %state_area = 'VALIDATE_CUSTOMER'  ) TO reported-travel.

      IF travel_s-CustomerId IS INITIAL.
        APPEND VALUE #( %tky = travel_s-%tky ) TO failed-travel.

        APPEND VALUE #( %tky = travel_s-%tky
                        %state_area = 'VALIDATE_CUSTOMER'
                        %msg        = NEW /dmo/cm_flight_messages(
                                                          textid    = /dmo/cm_flight_messages=>enter_customer_id
                                                          severity  = if_abap_behv_message=>severity-error )
                        %element-CustomerID = if_abap_behv=>mk-on
                      ) TO reported-travel.
      ELSEIF travel_s-CustomerId IS NOT INITIAL AND NOT line_exists( valid_customers[ customer_id = travel_s-CustomerId ] ).
        APPEND VALUE #( %tky = travel_s-%tky ) TO failed-travel.

        APPEND VALUE #( %tky    = travel_s-%tky
                        %state_area = 'VALIDATE_CUSTOMER'
                         %msg        = NEW /dmo/cm_flight_messages(
                                                          textid    = /dmo/cm_flight_messages=>enter_customer_id
                                                          severity  = if_abap_behv_message=>severity-error )
                        %element-CustomerID = if_abap_behv=>mk-on
                      ) TO reported-travel.

      ENDIF.


    ENDLOOP.

  ENDMETHOD.

  METHOD validateDates.
    READ ENTITIES OF zr_rap_100_travel IN LOCAL MODE
       ENTITY Travel
         FIELDS (  BeginDate EndDate TravelID )
         WITH CORRESPONDING #( keys )
       RESULT DATA(travels).

    LOOP AT travels INTO DATA(travel_s).

      APPEND VALUE #(  %tky               = travel_s-%tky
                       %state_area        = 'VALIDATE_DATES' ) TO reported-travel.

      IF travel_s-BeginDate IS INITIAL.
        APPEND VALUE #( %tky = travel_s-%tky ) TO failed-travel.

        APPEND VALUE #( %tky               = travel_s-%tky
                        %state_area        = 'VALIDATE_DATES'
                         %msg              = NEW /dmo/cm_flight_messages(
                                                                textid   = /dmo/cm_flight_messages=>enter_begin_date
                                                                severity = if_abap_behv_message=>severity-error )
                        %element-BeginDate = if_abap_behv=>mk-on ) TO reported-travel.
      ENDIF.
      IF travel_s-BeginDate < cl_abap_context_info=>get_system_date( ) AND travel_s-BeginDate IS NOT INITIAL.
        APPEND VALUE #( %tky               = travel_s-%tky ) TO failed-travel.

        APPEND VALUE #( %tky               = travel_s-%tky
                        %state_area        = 'VALIDATE_DATES'
                         %msg              = NEW /dmo/cm_flight_messages(
                                                                begin_date = travel_s-BeginDate
                                                                textid     = /dmo/cm_flight_messages=>begin_date_on_or_bef_sysdate
                                                                severity   = if_abap_behv_message=>severity-error )
                        %element-BeginDate = if_abap_behv=>mk-on ) TO reported-travel.
      ENDIF.
      IF travel_s-EndDate IS INITIAL.
        APPEND VALUE #( %tky = travel_s-%tky ) TO failed-travel.

        APPEND VALUE #( %tky               = travel_s-%tky
                        %state_area        = 'VALIDATE_DATES'
                         %msg                = NEW /dmo/cm_flight_messages(
                                                                textid   = /dmo/cm_flight_messages=>enter_end_date
                                                                severity = if_abap_behv_message=>severity-error )
                        %element-EndDate   = if_abap_behv=>mk-on ) TO reported-travel.
      ENDIF.
      IF travel_s-EndDate < travel_s-BeginDate AND travel_s-BeginDate IS NOT INITIAL
                                           AND travel_s-EndDate IS NOT INITIAL.
        APPEND VALUE #( %tky = travel_s-%tky ) TO failed-travel.

        APPEND VALUE #( %tky               = travel_s-%tky
                        %state_area        = 'VALIDATE_DATES'
                        %msg               = NEW /dmo/cm_flight_messages(
                                                                textid     = /dmo/cm_flight_messages=>begin_date_bef_end_date
                                                                begin_date = travel_s-BeginDate
                                                                end_date   = travel_s-EndDate
                                                                severity   = if_abap_behv_message=>severity-error )
                        %element-BeginDate = if_abap_behv=>mk-on
                        %element-EndDate   = if_abap_behv=>mk-on ) TO reported-travel.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD deductDiscount.
    DATA travels_for_update TYPE TABLE FOR UPDATE zr_rap_100_travel.
    DATA(keys_with_valid_discount) = keys.

    "Set discount to 30% (S)
    "read relevant travel instance data (only booking fee)
*    READ ENTITIES OF zr_rap_100_travel IN LOCAL MODE
*    ENTITY travel
*    FIELDS ( BookingFee )
*    WITH CORRESPONDING #( keys_with_valid_discount )
*    RESULT DATA(travels).


*    LOOP AT travels ASSIGNING FIELD-SYMBOL(<travel>).
*        DATA(reduce_fee) = <travel>-BookingFee * ( 1 - 3 / 10 ).
*
*        APPEND VALUE #( %tky    = <travel>-%tky
*                        bookingfee = reduce_fee ) TO travels_for_update.
*    ENDLOOP.
    "Set discount to 30% (E)

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    "Set Discount based on value in parameter(S)

    "Check and handle invalid discount values
    LOOP AT keys_with_valid_discount ASSIGNING FIELD-SYMBOL(<key_with_valid_discount>)
        WHERE %param-discount_percent IS INITIAL OR %param-discount_percent GT 100 OR %param-discount_percent LE 0.

      "report invalid discount value appropriately
      APPEND VALUE #( %tky   = <key_with_valid_discount>-%tky ) TO failed-travel.

      APPEND VALUE #( %tky   = <key_with_valid_discount>-%tky
                      %msg   = NEW /dmo/cm_flight_messages(
                                                        textid   = /dmo/cm_flight_messages=>discount_invalid
                                                        severity = if_abap_behv_message=>severity-error
                                                          )
                     %element-TotalPrice = if_abap_behv=>mk-on
                     %op-%action-deductDiscount = if_abap_behv=>mk-on
                     ) TO reported-travel.

      "remove invalid discount value
      DELETE keys_with_valid_discount.

    ENDLOOP.

    "check and go ahead with valid discount value
    CHECK keys_with_valid_discount IS NOT INITIAL.

    "read relevant instance data (only booking fee)
    READ ENTITIES OF zr_rap_100_travel IN LOCAL MODE
    ENTITY travel
    FIELDS ( BookingFee )
    WITH CORRESPONDING #( keys_with_valid_discount )
    RESULT DATA(travels).

    LOOP AT travels ASSIGNING FIELD-SYMBOL(<travels>).
      DATA percentage TYPE decfloat16.
      DATA(discount_percent) = keys_with_valid_discount[ KEY draft %tky = <travels>-%tky ]-%param-discount_percent.
      percentage = discount_percent / 100.
      DATA(reduced_fee) = <travels>-BookingFee * ( 1 - percentage ).

      APPEND VALUE #( %tky   = <travels>-%tky
                      BookingFee = reduced_fee ) TO travels_for_update.
    ENDLOOP.

    "Set Discount based on value in parameter(E)
    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

    "update data with reduce fee
    MODIFY ENTITIES OF zr_rap_100_travel IN LOCAL MODE
    ENTITY travel
    UPDATE FIELDS ( BookingFee )
    WITH travels_for_update.

    "read changed data for action result
    READ ENTITIES OF zr_rap_100_travel IN LOCAL MODE
    ENTITY travel
    ALL FIELDS WITH
    CORRESPONDING #( travels )
    RESULT DATA(travel_with_discount).

    "set action result
    result = VALUE #( FOR travel IN travel_with_discount ( %tky = travel-%tky
                                                           %param = travel ) ).
  ENDMETHOD.

  METHOD copyTravel.
    DATA : travels TYPE TABLE FOR CREATE zr_rap_100_travel.

    "remove travel instances with initial %cid
    READ TABLE keys WITH KEY %cid = '' INTO DATA(key_with_initial_cid).
    ASSERT key_with_initial_cid IS INITIAL.

    "Read the data from the travel instances to be copied
    READ ENTITIES OF zr_rap_100_travel IN LOCAL MODE
    ENTITY travel
    ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(travel_read_result)
    FAILED failed.

    LOOP AT travel_read_result ASSIGNING FIELD-SYMBOL(<travel>).
      "fill in travel container for creating new travel instance
      APPEND VALUE #( %cid        = keys[ KEY entity %key = <travel>-%key ]-%cid
                      %is_draft   = keys[ KEY entity %key = <travel>-%key ]-%param-%is_draft
                      %data       = CORRESPONDING #( <travel> EXCEPT travelid ) )
                      TO travels ASSIGNING FIELD-SYMBOL(<new_travel>).

      "adjust the copied travel instance data
      "begindate must be on or after system date
      <new_travel>-BeginDate = cl_abap_context_info=>get_system_date(  ).
      "enddate must be after begindate
      <new_travel>-EndDate   = cl_abap_context_info=>get_system_date(  ) + 30.
      "overall status of new instances must be set to open ('O')
      <new_travel>-OverallStatus = travel_status-open.
    ENDLOOP.

    "create new BO instances
    MODIFY ENTITIES OF zr_rap_100_travel IN LOCAL MODE
    ENTITY travel
    CREATE FIELDS ( AgencyId CustomerId BeginDate EndDate BookingFee
                    TotalPrice CurrencyCode OverallStatus Description )
    WITH travels
    MAPPED DATA(mapped_create).

    "set the new BO instances
    mapped-travel = mapped_create-travel.

  ENDMETHOD.

  METHOD acceptTravel.
    MODIFY ENTITIES OF zr_rap_100_travel IN LOCAL MODE
    ENTITY travel
    UPDATE FIELDS ( OverallStatus )
    WITH VALUE #( FOR key IN keys ( %tky = key-%tky
                                    OverallStatus = travel_status-accepted ) )
    FAILED failed
    REPORTED reported.

    "read changes data for action result
    READ ENTITIES OF zr_rap_100_travel IN LOCAL MODE
    ENTITY travel
    ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(travels).

    "set the action result parameter
    result = VALUE #( FOR travel IN travels ( %tky = travel-%tky
                                              %param = travel ) ).

  ENDMETHOD.

  METHOD rejectTravel.
    MODIFY ENTITIES OF zr_rap_100_travel IN LOCAL MODE
    ENTITY travel
    UPDATE FIELDS ( OverallStatus )
    WITH VALUE #( FOR key IN keys ( %tky = key-%tky
                                    OverallStatus = travel_status-rejected ) )
    FAILED failed
    REPORTED reported.

    "read changes data for action result
    READ ENTITIES OF zr_rap_100_travel IN LOCAL MODE
    ENTITY travel
    ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(travels).

    "set the action result parameter
    result = VALUE #( FOR travel IN travels ( %tky = travel-%tky
                                              %param = travel ) ).
  ENDMETHOD.

  METHOD get_instance_features.
    " read relevant travel instance data
    READ ENTITIES OF zr_rap_100_travel IN LOCAL MODE
      ENTITY travel
         FIELDS ( TravelID OverallStatus )
         WITH CORRESPONDING #( keys )
       RESULT DATA(travels)
       FAILED failed.

    " evaluate the conditions, set the operation state, and set result parameter
    result = VALUE #( FOR travel IN travels
                       ( %tky                   = travel-%tky

                         %features-%update      = COND #( WHEN travel-OverallStatus = travel_status-accepted
                                                          THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled   )
                         %features-%delete      = COND #( WHEN travel-OverallStatus = travel_status-open
                                                          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled   )
                         %action-Edit           = COND #( WHEN travel-OverallStatus = travel_status-accepted
                                                          THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled   )
                         %action-acceptTravel   = COND #( WHEN travel-OverallStatus = travel_status-accepted
                                                          THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled   )
                         %action-rejectTravel   = COND #( WHEN travel-OverallStatus = travel_status-rejected
                                                          THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled   )
*                           %action-deductDiscount = COND #( WHEN travel-OverallStatus = travel_status-open
*                                                            THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled   )
                      ) ).

  ENDMETHOD.

ENDCLASS.
