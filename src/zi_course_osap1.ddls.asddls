@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Data Definition for ZCOURSE_OSAP1'
define root view entity ZI_COURSE_OSAP1 as select from zcourse_osap1 as Course
  composition [0..*] of ZI_SCHEDULE_OSAP1 as _Schedule
  association [0..1] to I_Currency        as _Currency on $projection.CurrencyCode = _Currency.Currency
  association [0..1] to I_Country         as _Country  on $projection.Country = _Country.Country

{
  key Course.course_uuid           as CourseUuid,
      Course.course_id             as CourseId,
      Course.course_name           as CourseName,
      Course.course_length         as CourseLength,
      Course.country               as Country,
      Course.price                 as Price,
      Course.currency_code         as CurrencyCode,
      @Semantics.systemDateTime.lastChangedAt: true
      Course.last_changed_at       as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      Course.local_last_changed_at as LocalLastChangedAt,

      _Schedule,
      _Currency,
      _Country
}
