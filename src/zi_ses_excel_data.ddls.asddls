@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'SES Excel Data'
@Metadata.allowExtensions: true
define view entity ZI_SES_EXCEL_DATA as select from zswes_db
association to parent zi_ses_parent as _ses_file on $projection.End_User = _ses_file.end_user
{
    key zswes_db.end_user as End_User,
    key zswes_db.entrysheet as Entrysheet,
    key zswes_db.ebeln as Ebeln,
    key zswes_db.ebelp as Ebelp,
    zswes_db.ext_number as Ext_Number,
    zswes_db.begdate as Begdate,
    zswes_db.enddate as Enddate,
    zswes_db.quantity as Quantity,
    zswes_db.base_uom as BaseUom,
    zswes_db.fin_entry as Fin_Entry,
    zswes_db.error as Error,
    zswes_db.error_message as Error_Message,
    
    _ses_file // Make association public
}
