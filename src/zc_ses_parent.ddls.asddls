@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption View for File'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZC_SES_PARENT
    provider contract transactional_query
    as projection on ZI_SES_PARENT
{
    key end_user,
    //status,
    @EndUserText.label: 'Processing Status'
    FileStatus as status,
    CriticalityStatus,
    HideExcel,
    Attachment,
    MimeType,
    Filename,
    Local_Created_By,
    Local_Created_At,
    Local_Last_Changed_By,
    @EndUserText.label: 'Last Action On'
    Local_Last_Changed_At,
    Last_Changed_At,
    /* Associations */
    _ses_excel : redirected to composition child zc_ses_excel
//    _association_name // Make association public
}
