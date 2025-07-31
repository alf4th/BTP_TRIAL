@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption View for SES Excel Data'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED    
}
@Metadata.allowExtensions: true
define view entity ZC_SES_EXCEL as projection on ZI_SES_EXCEL_DATA
{
    key End_User,
    key Entrysheet,
    key Ebeln,
    key Ebelp,
    Ext_Number,
    Begdate,
    Enddate,
    Quantity,
    BaseUom,
    Fin_Entry,
    Error,
    Error_Message,
    /* Associations */
    _ses_file : redirected to parent zc_ses_parent
}
