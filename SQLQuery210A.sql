-->>>NEW VERSION

if object_id('tempdb..#aa') is not null  drop table #aa
if object_id('tempdb..#BB') is not null  drop table #BB
if object_id('tempdb..#T_1') is not null  drop table #T_1
if object_id('tempdb..#T_2') is not null  drop table #T_2
if object_id('tempdb..#T_3') is not null  drop table #T_3
if object_id('tempdb..#FINAL') is not null  drop table #FINAL
if object_id('tempdb..#Years') is not null  drop table #Years
if object_id('tempdb..#TEMP_YR') is not null  drop table #TEMP_YR
if object_id('tempdb..#7YEARS') is not null  drop table #7YEARS



/*
declare @CW as date = (select max(snapshotDate) from NPDW_Report.sabi.v_dim_0250_SnapshotPeriod where periodType = 'Weekly' and ActivityIsProcessed = 1)
declare @rpProject as varchar(20) = '73113'
declare @rpReport as varchar(1) = '0'
declare @rpOutageSegment as varchar(3) = '3'
declare @rpPIEPCCC as varchar(5) = '5'
declare @rpResources as varchar(10)= '87JM'
declare @rpGraphStart as varchar(6) = '201001'
declare @rpGraphEnd as varchar(6) = '202701'
*/

declare @irpYear as varchar(4)  = (select case 	when @rpReport = '1' then '2015'
												when @rpReport = '2' then '2018'
												when @rpReport = '3' then '2020'
												when @rpReport = '4' then '2022'
												else ltrim(str(year(getdate())))
												end
									)
print @irpYear
SELECT

  
  aa.Snapshot_Date
, rtp.BR_WorkWeek as WW
, rtp.BR_FiscalMonth as FiscalMonth
, aa.Activity_Key
, aa.ResourceAssign_Key
, aa.Resource_ID
, SUM(rtp.Planned_Hours) as Hours


INTO  #aa

FROM		NPDW_Report.sabi.v_fact_0211d_ResourceAssignmentL3_Weekly aa

INNER JOIN	NPDW_Report.sabi.v_fact_0212a_ResourceTimePhase_Weekly rtp

			ON aa.Activity_Key = rtp.Activity_Key
			AND aa.Snapshot_Date = rtp.Snapshot_Date
			AND aa.ResourceAssign_Key = rtp.ResourceAssign_Key
			AND rtp.BR_Resource_Type = 'RT_Labor'

WHERE
	aa.Snapshot_Date >= dateadd(d,-7, @CW) and aa.Snapshot_Date <= @CW
AND	aa.Activity_Type IN ('TT_Task','TT_LOE')
AND	aa.BR_CM_ACTIVITY_LEVEL_Val = '3'
AND	aa.BR_NR_EXECUTION_WINDOWS_Val NOT LIKE ('%C')
AND aa.BR_NR_OUTAGE_SEGMENT_Val IN (@rpOutageSegment) --in ('0','1','2','2A','2B','3','4','5','N/A','CONT')--
AND	aa.BR_ProjectNumber IN (@rpProject)
AND	aa.BR_PIEPCCC IN (@rpPIEPCCC) --('2','5','6') --
--AND (aa.Resource_Type = 'RT_Labor' or isnull(aa.Resource_Type,'XX') = 'XX')
AND rtp.Planned_Hours > 0
AND aa.Resource_ID in (@rpResources) -- ('87FM','87JM','87SF','BABD','BBBD','BFBD','BBMBD','BXBD') --

GROUP BY 
aa.Snapshot_Date,
rtp.BR_WorkWeek,
rtp.BR_FiscalMonth, 
aa.Activity_Key,
aa.ResourceAssign_Key,
aa.Resource_ID

create index ix_1 on #aa ( Activity_Key, Snapshot_Date, ResourceAssign_Key)
create index ix_2 on #aa ( Snapshot_Date, Resource_ID)

CREATE TABLE #7YEARS
(
   [Year]	varchar(4),
   rn		int
)


INSERT INTO #7YEARS
select a.[Year],
ROW_NUMBER() OVER(ORDER BY a.Year ASC) as rn  
from
(
select distinct year(date) as Year from NPDW_Report.sabi.v_dim_0254_TimePhasePeriod 
) a
where
(
(@rpReport in ('0','5') and a.Year  >=  @irpYear - 3 and a.year <= @irpYear + 10 )
or
(@rpReport in('1','2','3','4') and a.Year >= @irpYear and a.Year <= @irpYear + 10)
)
order by a.year


declare @minYear as varchar(4) = (select Year from #7YEARS where rn = 1)
--print @minYear
declare @maxYear as varchar(4) = (select Year from #7YEARS where rn = 7)
--print @maxYear
SELECT 
  CASE WHEN aa.Snapshot_Date = @CW then 'CW' else 'LW' end as RecordType
, aa.Snapshot_Date
, aa.FiscalMonth as FM
, case 	when @rpReport = '1' and left(aa.FiscalMonth,4) < '2015' then '2015'
	    when @rpReport = '2' and left(aa.FiscalMonth,4) < '2018' then '2018'
	    when @rpReport = '3' and left(aa.FiscalMonth,4) < '2020' then '2020'
	    when @rpReport = '4' and left(aa.FiscalMonth,4) < '2022' then '2022'
	    when @rpReport in ('0','5') and left(aa.FiscalMonth,4) < @minYear then @minYear
	    when @rpReport in ('0','5') and left(aa.FiscalMonth,4) > @maxYear then @maxYear
		else left(aa.FiscalMonth,4) --not used
  end as Year

, case 	
	when @rpReport = '1' and left(aa.FiscalMonth,4) < '2015' then '01'
	when @rpReport = '2' and left(aa.FiscalMonth,4) < '2018' then '01'
	when @rpReport = '3' and left(aa.FiscalMonth,4) < '2020' then '01'
	when @rpReport = '4' and left(aa.FiscalMonth,4) < '2022' then '01'
	when @rpReport in ('0','5') and	left(aa.FiscalMonth,4) < @minYear then '01'
	when @rpReport in ('0','5') and left(aa.FiscalMonth,4) > @maxYear then '01'
	else right(aa.FiscalMonth,2) 
 end as Month

, r.BR_CM_RESOURCE_GROUP_Name as ResourceCode
, r.BR_CM_RESOURCE_GROUP_Val
, aa.Resource_ID
, r.Resource_Name
, m.BR_ProgramWBS
, m.BR_UnitWBS
, m.BR_BundleWBS
, m.BR_BundleTitleShort as Bundle
, m.BR_ProjectNumber as ProjectNumber
, m.BR_ProjectTitleShort as ProjectTitle
, m.BR_ProjectNumber + ' - ' + m.BR_ProjectTitleLong as Project
, m.BR_Vendor as Vendor
, m.BR_VendorDescription
, sum(aa.Hours) as Hours
INTO #BB
FROM #aa aa
INNER JOIN NPDW_Report.sabi.v_fact_0211d_ResourceAssignmentL3_Weekly m
			ON aa.Activity_Key = m.Activity_Key
			AND aa.Snapshot_Date = m.Snapshot_Date
			AND aa.ResourceAssign_Key = m.ResourceAssign_Key
INNER JOIN	 NPDW_Report.sabi.v_fact_0213a_ResourceCodeAssign_Weekly r
			ON aa.Snapshot_Date = r.Snapshot_Date
			AND aa.Resource_ID = r.Resource_ID

Group by 
  aa.Snapshot_Date
, aa.FiscalMonth 
, case 	when @rpReport = '1' and left(aa.FiscalMonth,4) < '2015' then '2015'
	    when @rpReport = '2' and left(aa.FiscalMonth,4) < '2018' then '2018'
	    when @rpReport = '3' and left(aa.FiscalMonth,4) < '2020' then '2020'
	    when @rpReport = '4' and left(aa.FiscalMonth,4) < '2022' then '2022'
	    when @rpReport in ('0','5') and left(aa.FiscalMonth,4) < @minYear then @minYear
	    when @rpReport in ('0','5') and left(aa.FiscalMonth,4) > @maxYear then @maxYear
		else left(aa.FiscalMonth,4) --not used
  end 

, case 	
	when @rpReport = '1' and left(aa.FiscalMonth,4) < '2015' then '01'
	when @rpReport = '2' and left(aa.FiscalMonth,4) < '2018' then '01'
	when @rpReport = '3' and left(aa.FiscalMonth,4) < '2020' then '01'
	when @rpReport = '4' and left(aa.FiscalMonth,4) < '2022' then '01'
	when @rpReport in ('0','5') and	left(aa.FiscalMonth,4) < @minYear then '01'
	when @rpReport in ('0','5') and left(aa.FiscalMonth,4) > @maxYear then '01'
	else right(aa.FiscalMonth,2) 
 end 
, r.BR_CM_RESOURCE_GROUP_Name
, r.BR_CM_RESOURCE_GROUP_Val
, aa.Resource_ID
, r.Resource_Name
, m.BR_ProgramWBS
, m.BR_UnitWBS
, m.BR_BundleWBS
, m.BR_BundleTitleShort 
, m.BR_ProjectNumber 
, m.BR_ProjectTitleShort 
, m.BR_ProjectNumber + ' - ' + m.BR_ProjectTitleLong 
, m.BR_Vendor
, m.BR_VendorDescription

--select * from #BB fm, year and month ok
declare @MIN as varchar(6) = (select min(Year + Month) from #BB)
declare @MAX as varchar(6) = (select max(Year + Month) from #BB)

select b.Year,
ROW_NUMBER() OVER(ORDER BY b.Year ASC) as rn 
INTO #TEMP_YR
From
(select distinct 
left(t.FiscalMonth,4) as Year
FROM NPDW_Report.sabi.v_dim_0254_TimePhasePeriod t
where t.FiscalMonth Between @MIN and @MAX ) b

select b.Year,
cast(0 as int) as rn 
INTO #Years 
From #TEMP_YR b

UNION
select c.Year,
cast(0 as int) as rn 
From
(select distinct 
left(t.FiscalMonth,4) as Year
FROM NPDW_Report.sabi.v_dim_0254_TimePhasePeriod t
 where t.FiscalMonth Between case when @rpGraphStart < @MIN then @rpGraphStart else @MIN end and case when @rpGraphEnd> @MAX then @rpGraphEnd else @MAX end) c

/*
update y
set y.rn = t.rn
from #Years y
inner join #TEMP_YR t
on y.Year = t.Year
*/
update y
set y.rn = t.rn
from #Years y
inner join #7YEARS t
on y.Year = t.Year

select top 1
  'CW' as RecordType
, aa.Snapshot_Date
, aa.FM
, cast(space(4) as varchar(4)) as Year
, cast(space(2) as varchar(2)) as Month
, aa.ResourceCode
, aa.BR_CM_RESOURCE_GROUP_Val
, aa.Resource_ID
, aa.Resource_Name
, aa.BR_ProgramWBS
, aa.BR_UnitWBS
, aa.BR_BundleWBS
, aa.Bundle
, aa.ProjectNumber
, aa.ProjectTitle
, aa.Project
, aa.Vendor
, aa.BR_VendorDescription
, 0 as Hours
INTO #T_1
FROM #BB aa

CREATE TABLE #T_2
(
   id    int not null identity(1,1) primary key,
   FM varchar(6),
   Hours numeric (17,6),
   Cumm_Hours numeric (17,6)
)

Insert into #T_2
(FM,
Hours)
select distinct 
t.FiscalMonth,
isnull(b.Hours,0)
FROM NPDW_Report.sabi.v_dim_0254_TimePhasePeriod t
LEFT JOIN  (select Year + Month as FM, sum(Hours) as Hours
			from #BB 
			where RecordType = 'CW'
			group by Year+Month) b
on t.FiscalMonth = b.FM
WHERe FiscalMonth between case when @rpGraphStart < @MIN then @rpGraphStart else @MIN end and case when @rpGraphEnd> @MAX then @rpGraphEnd else @MAX end
ORDER BY FiscalMonth

SELECT a.id, a.FM, a.Hours, (SELECT SUM(isnull(b.Hours,0))
                       FROM #T_2 b
                       WHERE b.id <= a.id) as Cumm_Hrs 
INTO  #T_3	
FROM   #T_2 a
ORDER BY a.id

SELECT 
b.Year + b.Month as FM_Mod,
b.* 
INTO #FINAL
from #BB b



UNION ALL
select
  t2.FM	
, aa.RecordType
, aa.Snapshot_Date
, aa.FM
, left(t2.FM,4) 
, right(t2.FM,2)
, aa.ResourceCode
, aa.BR_CM_RESOURCE_GROUP_Val
, aa.Resource_ID
, aa.Resource_Name
, aa.BR_ProgramWBS
, aa.BR_UnitWBS
, aa.BR_BundleWBS
, aa.Bundle
, aa.ProjectNumber
, aa.ProjectTitle
, aa.Project
, aa.Vendor
, aa.BR_VendorDescription
, 0 as Hours
FROM #T_1 aa,#T_2 t2

--This adds Monthly Cumm Values
UNION ALL
select
  t3.FM	
, 'CU'
, aa.Snapshot_Date
, aa.FM
, left(t3.FM,4) 
, right(t3.FM,2)
, aa.ResourceCode
, aa.BR_CM_RESOURCE_GROUP_Val
, aa.Resource_ID
, aa.Resource_Name
, aa.BR_ProgramWBS
, aa.BR_UnitWBS
, aa.BR_BundleWBS
, aa.Bundle
, aa.ProjectNumber
, aa.ProjectTitle
, aa.Project
, aa.Vendor
, aa.BR_VendorDescription
, Cumm_Hrs as Hours
FROM #T_1 aa,#T_3 t3

select 
 
  aa.RecordType
, aa.Snapshot_Date
, aa.FM
, aa.FM_Mod	
,  y.rn
, aa.Year
, aa.Month
, aa.ResourceCode
, aa.BR_CM_RESOURCE_GROUP_Val
, aa.Resource_ID
, aa.Resource_Name
, aa.BR_ProgramWBS
, aa.BR_UnitWBS
, aa.BR_BundleWBS
, aa.Bundle
, aa.ProjectNumber
, aa.ProjectTitle
, aa.Project
, aa.Vendor
, aa.BR_VendorDescription
, aa.Hours
from #FINAL  aa
left JOIN #Years y
on aa.Year = y.Year