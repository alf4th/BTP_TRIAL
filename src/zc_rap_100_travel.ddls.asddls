@Metadata.allowExtensions: true
@EndUserText.label: 'Projection TEST View Travel'
@AccessControl.authorizationCheck: #CHECK
@ObjectModel.sapObjectNodeType.name: 'ZRAP_100_TRAVEL'
@ObjectModel.semanticKey: [ 'TravelId' ]
@Search.searchable: true
define root view entity ZC_RAP_100_TRAVEL
  provider contract transactional_query
  as projection on ZR_RAP_100_TRAVEL
{ 
  @Search.defaultSearchElement: true
  @Search.fuzzinessThreshold: 0.90
  key TravelId,
  
  @Search.defaultSearchElement: true
  @ObjectModel.text.element: [ 'AgencyName' ] //display Description(NAME) for AgencyId
  @Consumption.valueHelpDefinition: [{ entity : {name: '/DMO/I_Agency_StdVH', element: 'AgencyID' }, useForValidation: true }]
  AgencyId,
  _Agency.Name      as AgencyName,
  
  @Search.defaultSearchElement: true
  @ObjectModel.text.element: [ 'CustomerName' ]
  @Consumption.valueHelpDefinition: [{ entity :{ name:'/DMO/I_Customer_StdVH',element: 'CustomerID' }, useForValidation: true }]
  CustomerId,
  _Customer         as CustomerName,
  BeginDate,
  EndDate,
  BookingFee,
  TotalPrice,
  
  @Semantics.currencyCode: true
  @Consumption.valueHelpDefinition: [{ entity:{ name:'I_CurrencyStdVH',element:'Currency' },useForValidation: true }]
  CurrencyCode,
  Description,
  
  @ObjectModel.text.element: [ 'OverallStatusText' ]
  @Consumption.valueHelpDefinition: [{ entity:{name:'/DMO/I_Overall_Status_VH',element:'OverallStatus'},useForValidation: true }]
  OverallStatus,
  _OverallStatus._Text.Text as OverallStatusText : localized,
  Attachment,
  MimeType,
  FileName,
  CreatedBy,
  CreateAt,
  LocalLastChangedBy,
  LocalLastChangedAt,
  LastChangedAt
  
}
