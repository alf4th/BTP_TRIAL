@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Data Definition Schedule'
define view entity ZI_SCHEDULE_OSAP1 as select from zschedule_osap1 as Schedule
  association to parent ZI_COURSE_OSAP1 as _Course on $projection.CourseUuid = _Course.CourseUuid
{

  key Schedule.schedule_uuid         as ScheduleUuid,
      Schedule.course_begin          as CourseBegin,
      Schedule.course_uuid           as CourseUuid,
      Schedule.location              as Location,
      Schedule.trainer               as Trainer,
      Schedule.is_online             as IsOnline,
      @Semantics.systemDateTime.lastChangedAt: true
      Schedule.last_changed_at       as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      Schedule.local_last_changed_at as LocalLastChangedAt,

      _Course
}
