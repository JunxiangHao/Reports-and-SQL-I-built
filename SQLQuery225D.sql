/*DECLARE @rpPeriodType VARCHAR(20) SET @rpPeriodType = 'Weekly'
DECLARE @rpPeriod	DATETIME    	SET @rpPeriod = '2017-06-02'
DECLARE @rpProject  VARCHAR(10)  	SET @rpProject = '73113'
DECLARE @rpEVM  	VARCHAR(10)  	SET @rpEVM = 'DEL'
DECLARE @rpPIEPCCC	VARCHAR(2)  	SET @rpPIEPCCC = '5'
DECLARE @rpBaselineType VARCHAR(20) SET @rpBaselineType = 'Approved'
DECLARE @rpWindows VARCHAR(4) SET @rpWindows = '004'
DECLARE @rpSegment VARCHAR(3) SET @rpSegment = '1'
DECLARE @rpGroup  VARCHAR(10)  	SET @rpGroup = 'Bundle'*/


/* ******************************************************************************************** */
-->> RFR Actual hours are automatically loaded into ebx.v_INV_TF_0010_WEEKLY_PROJECT_BURDEN_Live
/* ******************************************************************************************** */

IF OBJECT_ID('tempdb..#inv') IS NOT NULL DROP TABLE #inv
IF OBJECT_ID('tempdb..#wbs') IS NOT NULL DROP TABLE #wbs
SELECT inv.* INTO #inv FROM NPDW_Report.ebx.v_INV_TF_0010_WEEKLY_PROJECT_BURDEN_Live inv 
SELECT wbs.* INTO #wbs FROM NPDW_Report.ebx.v_INV_TF_0040_WBS_LOOKUP_Live wbs

/* ******************************************************************************************** */
-->> Fiscal Week Mapping
/* ******************************************************************************************** */

IF OBJECT_ID('tempdb..#fw') IS NOT NULL DROP TABLE #fw

SELECT
	dd.FiscalWeek
,	ww.WorkWeek
INTO #fw
FROM ( SELECT dd.FiscalWeek, MAX(dd.Date) as Date FROM NPDW.npdw_rpt.v_dim_Date dd GROUP BY	dd.FiscalWeek) dd

LEFT JOIN NPDW.rpt.v_NR_WorkWeek ww
	ON	dd.Date BETWEEN CAST(ww.WWStartDate as Date) AND DATEADD(ww,1,CAST(ww.WWStartDate as Date))


/*************************************************************************************/
-->> CREATING THE SNAPSHOT TABLE FOR WEEKS, MONTHS, QUARTERS, YEARS
/*************************************************************************************/
IF OBJECT_ID('tempdb..#sp') IS NOT NULL DROP TABLE #sp

SELECT
	sp.SnapshotPeriod
,	sp.SnapshotDate
,	sp.PeriodType
,	sp.ActivityIsProcessed
INTO #sp
FROM NPDW_Report.sabi.v_dim_0250_SnapshotPeriod sp

UNION ALL

SELECT
	CASE 
	WHEN sp.SnapshotPeriod LIKE 'March%' THEN RIGHT(sp.SnapshotPeriod,4)+'Q1'
	WHEN sp.SnapshotPeriod LIKE 'June%' THEN RIGHT(sp.SnapshotPeriod,4)+'Q2'
	WHEN sp.SnapshotPeriod LIKE 'September%' THEN RIGHT(sp.SnapshotPeriod,4)+'Q3'
	WHEN sp.SnapshotPeriod LIKE 'December%' THEN RIGHT(sp.SnapshotPeriod,4)+'Q4'
	ELSE NULL
	END as SnapshotPeriod
,	sp.SnapshotDate 
,	'Quarter' as PeriodType
,	sp.ActivityIsProcessed


FROM NPDW_Report.sabi.v_dim_0250_SnapshotPeriod sp

WHERE
	sp.PeriodType = 'Monthly'
AND	CASE 
	WHEN sp.SnapshotPeriod LIKE 'March%' THEN RIGHT(sp.SnapshotPeriod,4)+'Q1'
	WHEN sp.SnapshotPeriod LIKE 'June%' THEN RIGHT(sp.SnapshotPeriod,4)+'Q2'
	WHEN sp.SnapshotPeriod LIKE 'September%' THEN RIGHT(sp.SnapshotPeriod,4)+'Q3'
	WHEN sp.SnapshotPeriod LIKE 'December%' THEN RIGHT(sp.SnapshotPeriod,4)+'Q4'
	ELSE NULL
	END IS NOT NULL

UNION ALL


SELECT
	CASE 
	WHEN sp.SnapshotPeriod LIKE 'December%' THEN RIGHT(sp.SnapshotPeriod,4)
	ELSE NULL
	END as SnapshotPeriod
,	sp.SnapshotDate 
,	'Year' as PeriodType
,	sp.ActivityIsProcessed

FROM NPDW_Report.sabi.v_dim_0250_SnapshotPeriod sp

WHERE
	sp.PeriodType = 'Monthly'
AND	CASE 
	WHEN sp.SnapshotPeriod LIKE 'December%' THEN RIGHT(sp.SnapshotPeriod,4)
	ELSE NULL
	END IS NOT NULL

/*************************************************************************************/
-->> ONE PERIOD BEFORE
/*************************************************************************************/

DECLARE @rpLastPeriod as date 
SET @rpLastPeriod = ( SELECT MAX(a.SnapshotDate) FROM #sp a WHERE a.PeriodType = @rpPeriodType AND a.SnapshotDate < @rpPeriod )

DECLARE @rpLast2Period as date 
SET @rpLast2Period = ( SELECT MAX(a.SnapshotDate) FROM #sp a WHERE a.PeriodType = @rpPeriodType AND a.SnapshotDate < @rpLastPeriod )

DECLARE @rpLastPeriodWeek as varchar(8) 
SET @rpLastPeriodWeek = ( SELECT MAX(ww.WorkWeek) FROM NPDW.rpt.v_NR_WorkWeek ww WHERE ww.WWStartDate <= @rpLastPeriod )

DECLARE @rpLast2PeriodWeek as varchar(8) 
SET @rpLast2PeriodWeek = ( SELECT MAX(ww.WorkWeek) FROM NPDW.rpt.v_NR_WorkWeek ww WHERE ww.WWStartDate <= @rpLast2Period )

DECLARE @rpPeriodWeek as varchar(8) 
SET @rpPeriodWeek = (SELECT MAX(ww.WorkWeek) FROM NPDW.rpt.v_NR_WorkWeek ww WHERE ww.WWStartDate <= @rpPeriod )

/*************************************************************************************/
-->> LIVE WORK WEEK
/*************************************************************************************/

DECLARE @LiveDate as date
SET @LiveDate =	(SELECT MAX(a.SnapshotDate) FROM NPDW_Report.sabi.v_dim_0250_SnapshotPeriod a WHERE a.PeriodType = 'Daily' AND a.ActivityIsProcessed = 1)

DECLARE @LiveWeek as varchar(8)
SET @LiveWeek = (SELECT a.WorkWeek FROM NPDW_Report.sabi.v_dim_0254_TimePhasePeriod a WHERE a.Date = @LiveDate)

IF 
	@rpPeriod NOT IN (SELECT a.SnapshotDate FROM NPDW_Report.sabi.v_dim_0250_SnapshotPeriod a WHERE a.PeriodType = 'Weekly' AND a.ActivityIsProcessed = 1)
BEGIN
IF OBJECT_ID('tempdb..#L2LOE_d') 	IS NOT NULL DROP TABLE #L2LOE_d
IF OBJECT_ID('tempdb..#l2l3_d') 	IS NOT NULL DROP TABLE #l2l3_d
IF OBJECT_ID('tempdb..#pb_d') 	IS NOT NULL DROP TABLE #pb_d
IF OBJECT_ID('tempdb..#cl_d') 	IS NOT NULL DROP TABLE #cl_d
IF OBJECT_ID('tempdb..#aa_d') 	IS NOT NULL DROP TABLE #aa_d
IF OBJECT_ID('tempdb..#dd_d') 	IS NOT NULL DROP TABLE #dd_d
IF OBJECT_ID('tempdb..#v_d')  	IS NOT NULL DROP TABLE #v_d	-- Earned
IF OBJECT_ID('tempdb..#tt_d') 	IS NOT NULL DROP TABLE #tt_d	-- MASTER TABLE | Planned | Forecast | Earned 

/* ******************************************************************************************** */
-->> Work Package Mapping
/* ******************************************************************************************** */
-->> There is a possibility that multiple work packages will have the same BR_L2WorkPackage coding. To ensure that level 3 activities are not duplicated when matching we use this logic to identify only a single work package for each BR_L2WorkPackage
; WITH a as
(
SELECT 
	aa.Snapshot_Date
,	aa.BR_L2WorkPackage
,	aa.Activity_ID
,	aa.Activity_Name
,	aa.Activity_ID+' - '+aa.Activity_Name as WorkPackage
,	aa.BR_NR_LOE_WORK_Val
,	ROW_NUMBER() OVER (PARTITION BY aa.Snapshot_Date, aa.BR_L2WorkPackage ORDER BY aa.BR_NR_LOE_WORK_Val DESC, aa.Activity_ID) as rn

FROM NPDW_Report.sabi.v_fact_0200c_ActivityL2_Daily aa
WHERE
	aa.Snapshot_Period = 'Live'
AND	aa.BR_ProjectNumber IN (@rpProject)
UNION ALL
SELECT 
	aa.Snapshot_Date
,	aa.BR_L2WorkPackage
,	aa.Activity_ID
,	aa.Activity_Name
,	aa.Activity_ID+' - '+aa.Activity_Name as WorkPackage
,	aa.BR_NR_LOE_WORK_Val
,	ROW_NUMBER() OVER (PARTITION BY aa.Snapshot_Date, aa.BR_L2WorkPackage ORDER BY aa.BR_NR_LOE_WORK_Val DESC, aa.Activity_ID) as rn

FROM NPDW_Report.sabi.v_fact_0210c_ActivityL2_Weekly aa

WHERE
	aa.Snapshot_Date = @rpLastPeriod
AND	aa.BR_ProjectNumber IN (@rpProject)
)
SELECT a.* INTO #l2l3_d FROM a WHERE a.rn = 1

CREATE INDEX idx_#l2l3d ON #l2l3_d (Snapshot_Date, BR_L2WorkPackage)

/*************************************************************************************/
-->> We use this table to select the right baseline for our planned tables.
/*************************************************************************************/

; WITH a_d as
(
SELECT DISTINCT
	pb.Project_ID
,	pb.BL_Project_ID
,	pb.BaselineType

FROM NPDW_Report.sabi.v_fact_0202f_ResourceTimePhase_BL pb
)

SELECT 
	pb.Project_ID
,	pb.BaselineType
,	ROW_NUMBER() OVER (PARTITION BY pb.Project_ID ORDER BY pb.BaselineType DESC) as rn
INTO #pb_d
FROM a_d pb

WHERE
	pb.BaselineType = @rpBaselineType
OR	pb.BaselineType = CASE WHEN @rpBaselineType = 'Recovery' THEN 'Approved' ELSE 'Homer' END

DELETE FROM #pb_d WHERE rn <> 1

CREATE INDEX idx_#pbd ON #pb_d (Project_ID, BaselineType)

/*************************************************************************************/
-->> Creating the summary table into which we'll dump our data
/*************************************************************************************/

CREATE TABLE #tt_d (
   [ProjectNumber]	VARCHAR(30)
  ,[Activity_ID]	VARCHAR(30)
  ,[Activity_Name]	VARCHAR(255)
  ,[PIEPCCC]		VARCHAR(10)
  ,[WorkWeek]		VARCHAR(10)
  ,[Hours]		DECIMAL(19,6)
  ,[HoursLTD]		DECIMAL(19,6)
  ,[Type]		VARCHAR(20)
)

/* ******************************************************************************************** */
-->> PLANNED / BASELINE
/* ******************************************************************************************** */

INSERT INTO #tt_d (
   [ProjectNumber]
  ,[Activity_ID]
  ,[Activity_Name]
  ,[PIEPCCC]
  ,[WorkWeek]
  ,[Hours]
  ,[HoursLTD]
  ,[Type]
)
SELECT
	aa.BR_ProjectNumber as ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
,	aa.BR_PIEPCCC
,	rtp.BR_WorkWeek as WorkWeek
,	SUM(rtp.Planned_Hours) as Forecast_Hours
,	0
,	'Planned'

FROM NPDW_Report.sabi.v_fact_0202f_ResourceTimePhase_BL rtp

INNER JOIN NPDW_Report.sabi.v_fact_0200c_ActivityL2_Daily aa
	ON	aa.Activity_Key = rtp.Activity_Key
	AND	aa.BR_CM_ACTIVITY_LEVEL_Val = '2'
	AND	aa.Snapshot_Period = 'Live'
	AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
	AND	aa.BR_PIEPCCC IN (@rpPIEPCCC)
	AND	aa.BR_ProjectNumber IN (@rpProject)

INNER JOIN #pb_d pb
	ON	pb.Project_ID = rtp.Project_ID
	AND	pb.BaselineType = rtp.BaselineType

WHERE
	rtp.BR_Resource_Type = 'RT_Labor'


GROUP BY
	aa.BR_ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
,	rtp.BR_WorkWeek
,	aa.BR_PIEPCCC

/* ******************************************************************************************** */
-->> APPROVED
/* ******************************************************************************************** */

INSERT INTO #tt_d (
   [ProjectNumber]
  ,[Activity_ID]
  ,[Activity_Name]
  ,[PIEPCCC]
  ,[WorkWeek]
  ,[Hours]
  ,[HoursLTD]
  ,[Type]
)
SELECT
	aa.BR_ProjectNumber as ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
,	aa.BR_PIEPCCC
,	rtp.BR_WorkWeek as WorkWeek
,	SUM(rtp.Planned_Hours) 
,	0
,	'Budget'

FROM NPDW_Report.sabi.v_fact_0202f_ResourceTimePhase_BL rtp

INNER JOIN NPDW_Report.sabi.v_fact_0200c_ActivityL2_Daily aa
	ON	aa.Activity_Key = rtp.Activity_Key
	AND	aa.BR_CM_ACTIVITY_LEVEL_Val = '2'
	AND	aa.Snapshot_Period = 'Live'
	AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
	AND	aa.BR_PIEPCCC IN (@rpPIEPCCC)
	AND	aa.BR_ProjectNumber IN (@rpProject)

WHERE
	rtp.BR_Resource_Type = 'RT_Labor'
AND 	rtp.BaselineType = 'Approved'


GROUP BY
	aa.BR_ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
,	rtp.BR_WorkWeek
,	aa.BR_PIEPCCC

/* ******************************************************************************************** */
-->> ACTUALS
/* ******************************************************************************************** */

INSERT INTO #tt_d (
   [ProjectNumber]
  ,[Activity_ID]
  ,[Activity_Name]
  ,[PIEPCCC]
  ,[WorkWeek]
  ,[Hours]
  ,[HoursLTD]
  ,[Type]
)
SELECT
	aa.BR_ProjectNumber
,	aa.Activity_ID
,   	aa.Activity_Name
,	aa.BR_PIEPCCC
,	tpp.WorkWeek
,	SUM(inv.Total_Hours)
,	0
,	'Actual'

FROM #inv inv

INNER JOIN  #wbs wbs
	ON	wbs.line_code =inv.alter_cost_c1_ 

INNER JOIN NPDW_Report.sabi.v_fact_0200c_ActivityL2_Daily aa
	ON	aa.Activity_ID = wbs.wp
	AND	aa.BR_ProjectNumber = wbs.project_no
	AND	aa.Snapshot_Period = 'Live'
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	aa.BR_PIEPCCC IN (@rpPIEPCCC)

INNER JOIN NPDW_Report.sabi.v_dim_0254_TimePhasePeriod tpp
	ON	tpp.Date = inv.week_ending

WHERE
	inv.week_ending <= @rpPeriod

GROUP BY
	aa.BR_ProjectNumber
,	aa.Activity_ID
,   	aa.Activity_Name
,	tpp.WorkWeek
,	aa.BR_PIEPCCC

INSERT INTO #tt_d (
   [ProjectNumber]
  ,[Activity_ID]
  ,[Activity_Name]
  ,[PIEPCCC]
  ,[WorkWeek]
  ,[Hours]
  ,[HoursLTD]
  ,[Type]
)
SELECT
	ah.Project as ProjectNumber
,	ah.project+ah.wbs as Activity_ID
,	ISNULL(aa.Activity_Name,'Not Available') as Activity_Name
,	aa.BR_PIEPCCC
,	tpp.WorkWeek as WorkWeek
,	SUM(ah.Hours) as Hours
,	0 as HoursLTD
,	'Actual' as Type

FROM NPDW_Report.ebx.v_AH_TF_0100_ACTUAL_HOUR_Live ah

INNER JOIN NPDW_Report.sabi.v_fact_0200c_ActivityL2_Daily aa
	ON	aa.Activity_ID = ah.project+ah.wbs
	AND	aa.Snapshot_Period = 'Live'

INNER JOIN NPDW_Report.sabi.v_dim_0252_ProjectMaster a
	ON	a.ProjectNumber = ah.Project
	AND	a.ProjectNumber IN (@rpProject)

INNER JOIN NPDW_Report.sabi.v_dim_0254_TimePhasePeriod tpp
	ON	tpp.Date = ah.date00
	AND	tpp.Date <= @rpPeriod

WHERE
	LEFT(ah.WBS,1) IN (@rpPIEPCCC)
AND	a.ProjectNumber NOT IN (SELECT #tt_d.ProjectNumber FROM #tt_d WHERE #tt_d.Type = 'Actual')

GROUP BY
	ah.Project
,	ah.wbs
,	aa.Activity_Name
,	tpp.WorkWeek
,	aa.BR_PIEPCCC

INSERT INTO #tt_d (
   [ProjectNumber]
  ,[Activity_ID]
  ,[Activity_Name]
  ,[PIEPCCC]
  ,[WorkWeek]
  ,[Hours]
  ,[HoursLTD]
  ,[Type]
)
SELECT 
	ft.Project as ProjectNumber
,	ft.WorkPackage as Activity_ID
,	ISNULL(aa.Activity_Name,'Not Available') as Activity_Name
,	aa.BR_PIEPCCC
,	fw.WorkWeek
,	SUM(ft.HoursQuantity) as Hours
,	0 as HoursLTD
,	'Actual' as Type

FROM NPDW.dbo.v_fact_FinTransaction ft

INNER JOIN NPDW.dbo.v_dim_FinSourceSystem fss
	ON	fss.FinSourceSystem_Key = ft.FinSourceSystem_FKey
	AND	fss.FinSourceSystemDesc = 'Tempus'

LEFT JOIN NPDW_Report.sabi.v_fact_0200c_ActivityL2_Daily aa
	ON	aa.Activity_ID = ft.WorkPackage
	AND	aa.BR_ProjectNumber = ft.Project
	AND	aa.Snapshot_Period = 'Live'

INNER JOIN #fw fw
	ON	fw.FiscalWeek = ft.FiscalWeek

INNER JOIN NPDW_Report.sabi.v_dim_0252_ProjectMaster a
	ON	a.ProjectNumber = ft.Project
	AND	a.ProjectNumber IN (@rpProject)
	AND	a.ProjectNumber NOT IN (SELECT DISTINCT ah.Project FROM NPDW_Report.ebx.v_AH_TF_0100_ACTUAL_HOUR_Live ah)
	AND	a.ProjectNumber NOT IN (SELECT DISTINCT ISNULL(wbs.project_no,'N/A') FROM #wbs wbs)

WHERE
	LEFT(ft.Local,1) IN (@rpPIEPCCC)
AND	fw.WorkWeek <= @rpPeriodWeek

GROUP BY
	ft.Project
,	ft.WorkPackage
,	aa.Activity_Name
,	fw.WorkWeek
,	aa.BR_PIEPCCC


INSERT INTO #tt_d (
   [ProjectNumber]
  ,[Activity_ID]
  ,[Activity_Name]
  ,[PIEPCCC]
  ,[WorkWeek]
  ,[Hours]
  ,[HoursLTD]
  ,[Type]
)
SELECT		
	onc.Project	as ProjectNumber
,	onc.Project+onc.WBS as Activity_ID
,	ISNULL(aa.Activity_Name,'Not Available') as Activity_Name
,	aa.BR_PIEPCCC
,	tpp.WorkWeek
,	SUM(onc.Hrs) as Hours
,	0 as HoursLTD
,	'Actual' as Type

FROM NPDW_Report.onc.v_fact_0311a_OncoreDetails_Daily	onc

LEFT JOIN NPDW_Report.sabi.v_fact_0200c_ActivityL2_Daily aa
	ON	aa.Activity_ID = onc.Project+onc.WBS
	AND	aa.BR_ProjectNumber = onc.Project
	AND	aa.Snapshot_Period = 'Live'
		
INNER JOIN NPDW_Report.sabi.v_dim_0254_TimePhasePeriod tpp		
	ON	tpp.Date = onc.TS_Date

INNER JOIN NPDW_Report.sabi.v_dim_0252_ProjectMaster a
	ON	a.ProjectNumber = onc.Project
	AND	a.ProjectNumber IN (@rpProject)
	AND	a.ProjectNumber NOT IN (SELECT DISTINCT ah.Project FROM NPDW_Report.ebx.v_AH_TF_0100_ACTUAL_HOUR_Live ah)
	AND	a.ProjectNumber NOT IN (SELECT DISTINCT ISNULL(wbs.project_no,'N/A') FROM #wbs wbs)
		
WHERE		
	LEFT(onc.WBS,1) IN (@rpPIEPCCC)
AND	onc.Approval_Status IN ('APPROVED','NEGATED','PENDING')	
AND	tpp.WorkWeek <= @rpPeriodWeek		

GROUP BY
	onc.Project
,	onc.WBS
,	aa.Activity_Name
,	tpp.WorkWeek
,	aa.BR_PIEPCCC




/* ******************************************************************************************** */
-->> FORECAST L2
/* ******************************************************************************************** */

INSERT INTO #tt_d (
   [ProjectNumber]
  ,[Activity_ID]
  ,[Activity_Name]
  ,[PIEPCCC]
  ,[WorkWeek]
  ,[Hours]
  ,[HoursLTD]
  ,[Type]
)
SELECT
	aa.BR_ProjectNumber as ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
,	aa.BR_PIEPCCC
,	rtp.BR_WorkWeek as WorkWeek
,	SUM(rtp.Planned_Hours) as Hours
,	0
,	'Forecast'

FROM NPDW_Report.sabi.v_fact_0202a_ResourceTimePhase_Daily rtp

INNER JOIN NPDW_Report.sabi.v_fact_0200c_ActivityL2_Daily aa
	ON	aa.Activity_Key = rtp.Activity_Key
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	aa.Snapshot_Period = 'Live'
	AND	aa.BR_CM_ACTIVITY_LEVEL_Val = '2'
	AND	aa.Activity_Type = 'TT_WBS'
	AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
	AND	aa.BR_PIEPCCC IN (@rpPIEPCCC)

WHERE
	rtp.Snapshot_Date = @rpPeriod
AND	rtp.BR_Resource_Type = 'RT_Labor'

GROUP BY
	aa.BR_ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
,	rtp.BR_WorkWeek
,	aa.BR_PIEPCCC

/* ******************************************************************************************** */
-->> FORECAST L2 LAST
/* ******************************************************************************************** */

INSERT INTO #tt_d (
   [ProjectNumber]
  ,[Activity_ID]
  ,[Activity_Name]
  ,[PIEPCCC]
  ,[WorkWeek]
  ,[Hours]
  ,[HoursLTD]
  ,[Type]
)
SELECT
	aa.BR_ProjectNumber as ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
,	aa.BR_PIEPCCC
,	rtp.BR_WorkWeek as WorkWeek
,	SUM(rtp.Planned_Hours) as Hours
,	0
,	'Forecast Last'

FROM NPDW_Report.sabi.v_fact_0212a_ResourceTimePhase_Weekly rtp

INNER JOIN NPDW_Report.sabi.v_fact_0210c_ActivityL2_Weekly aa
	ON	aa.Activity_Key = rtp.Activity_Key
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	aa.Snapshot_Date = @rpLastPeriod
	AND	aa.BR_CM_ACTIVITY_LEVEL_Val = '2'
	AND	aa.Activity_Type = 'TT_WBS'
	AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
	AND	aa.BR_PIEPCCC IN (@rpPIEPCCC)

WHERE
	rtp.Snapshot_Date = @rpLastPeriod
AND	rtp.BR_Resource_Type = 'RT_Labor'

GROUP BY
	aa.BR_ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
,	rtp.BR_WorkWeek
,	aa.BR_PIEPCCC



/* ******************************************************************************************** */
-->> Forecast burned rate
/* ******************************************************************************************** */

INSERT INTO #tt_d (
   [ProjectNumber]
  ,[Activity_ID]
  ,[Activity_Name]
  ,[PIEPCCC]
  ,[WorkWeek]
  ,[Hours]
  ,[HoursLTD]
  ,[Type]
)
SELECT
	aa.BR_ProjectNumber as ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
,	aa.BR_PIEPCCC
,	'2019WW01' as WorkWeek
,	SUM(rtp.Planned_Hours)/count(distinct(rtp.BR_WorkWeek)) as Hours
,	0
,	'Forecast burned rate'

FROM NPDW_Report.sabi.v_fact_0202a_ResourceTimePhase_Daily rtp

INNER JOIN NPDW_Report.sabi.v_fact_0200c_ActivityL2_Daily aa
	ON	aa.Activity_Key = rtp.Activity_Key
	AND	aa.BR_CM_ACTIVITY_LEVEL_Val = '2'
	AND	aa.Activity_Type = 'TT_WBS'
	AND	aa.Snapshot_Period = 'Live'
	AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	aa.BR_PIEPCCC IN (@rpPIEPCCC)

WHERE
	rtp.Snapshot_Date = @rpPeriod
AND	rtp.BR_Resource_Type = 'RT_Labor'

GROUP BY
	aa.BR_ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
--,	rtp.BR_WorkWeek
,	aa.BR_PIEPCCC

UNION ALL

SELECT
	aa.BR_ProjectNumber as ProjectNumber
,	'dummy' as Activity_ID
,	'dummy' as Activity_Name
,	aa.BR_PIEPCCC
,	'2019WW01' as WorkWeek
,	SUM(rtp.Planned_Hours)/count(distinct(rtp.BR_WorkWeek)) as Hours
,	0
,	'Forecast burned rate'

FROM NPDW_Report.sabi.v_fact_0202a_ResourceTimePhase_Daily rtp

INNER JOIN NPDW_Report.sabi.v_fact_0200c_ActivityL2_Daily aa
	ON	aa.Activity_Key = rtp.Activity_Key
	AND	aa.BR_CM_ACTIVITY_LEVEL_Val = '2'
	AND	aa.Activity_Type = 'TT_WBS'
	AND	aa.Snapshot_Period = 'Live'
	AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	aa.BR_PIEPCCC IN (@rpPIEPCCC)

WHERE
	rtp.Snapshot_Date = @rpPeriod
AND	rtp.BR_Resource_Type = 'RT_Labor'

GROUP BY
	aa.BR_ProjectNumber
--,	rtp.BR_WorkWeek
,	aa.BR_PIEPCCC

/* ******************************************************************************************** */
-->> Remaining L2
/* ******************************************************************************************** */

INSERT INTO #tt_d (
   [ProjectNumber]
  ,[Activity_ID]
  ,[Activity_Name]
  ,[PIEPCCC]
  ,[WorkWeek]
  ,[Hours]
  ,[HoursLTD]
  ,[Type]
)
SELECT
	aa.BR_ProjectNumber as ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
,	aa.BR_PIEPCCC
,	rtp.BR_WorkWeek as WorkWeek
,	SUM(rtp.Remaining_Hours) as Hours
,	0
,	'Remaining'

FROM NPDW_Report.sabi.v_fact_0202a_ResourceTimePhase_Daily rtp

INNER JOIN NPDW_Report.sabi.v_fact_0200c_ActivityL2_Daily aa
	ON	aa.Activity_Key = rtp.Activity_Key
	AND	aa.BR_CM_ACTIVITY_LEVEL_Val = '2'
	AND	aa.Activity_Type = 'TT_WBS'
	AND	aa.Snapshot_Period = 'Live'
	AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	aa.BR_PIEPCCC IN (@rpPIEPCCC)

WHERE
	rtp.Snapshot_Date = @rpPeriod
AND	rtp.BR_Resource_Type = 'RT_Labor'

GROUP BY
	aa.BR_ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
,	rtp.BR_WorkWeek
,	aa.BR_PIEPCCC

INSERT INTO #tt_d (
   [ProjectNumber]
  ,[Activity_ID]
  ,[Activity_Name]
  ,[PIEPCCC]
  ,[WorkWeek]
  ,[Hours]
  ,[HoursLTD]
  ,[Type]
)
SELECT
	aa.BR_ProjectNumber as ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
,	aa.BR_PIEPCCC
,	rtp.BR_WorkWeek as WorkWeek
,	SUM(rtp.Remaining_Hours) as Hours
,	0
,	'Remaining Last'

FROM NPDW_Report.sabi.v_fact_0212a_ResourceTimePhase_Weekly rtp

INNER JOIN NPDW_Report.sabi.v_fact_0210c_ActivityL2_Weekly aa
	ON	aa.Activity_Key = rtp.Activity_Key
	AND	aa.BR_CM_ACTIVITY_LEVEL_Val = '2'
	AND	aa.Activity_Type = 'TT_WBS'
	AND	aa.Snapshot_Date = @rpLastPeriod
	AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	aa.BR_PIEPCCC IN (@rpPIEPCCC)

WHERE
	rtp.Snapshot_Date = @rpLastPeriod
AND	rtp.BR_Resource_Type = 'RT_Labor'

GROUP BY
	aa.BR_ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
,	rtp.BR_WorkWeek
,	aa.BR_PIEPCCC

/* ******************************************************************************************** */
-->> FORECAST LEVEL 3
/* ******************************************************************************************** */

INSERT INTO #tt_d (
   [ProjectNumber]
  ,[Activity_ID]
  ,[Activity_Name]
  ,[PIEPCCC]
  ,[WorkWeek]
  ,[Hours]
  ,[HoursLTD]
  ,[Type]
)
SELECT
	aa.BR_ProjectNumber as ProjectNumber
,	ISNULL(l2aa.Activity_ID,aa.BR_ProjectNumber+aa.BR_PIEPCCC+'xxxx') as Activity_ID
,	ISNULL(l2aa.Activity_Name,'Not Available') as Activity_Name
,	aa.BR_PIEPCCC
,	rtp.BR_WorkWeek as WorkWeek
,	SUM(rtp.Planned_Hours)
,	0
,	'Forecast L3'

FROM 	NPDW_Report.sabi.v_fact_0202a_ResourceTimePhase_Daily rtp

INNER JOIN NPDW_Report.sabi.v_fact_0200d_ActivityL3_Daily aa
	ON	aa.Activity_Key = rtp.Activity_Key
	AND	aa.Snapshot_Date = rtp.Snapshot_Date
	AND	aa.BR_IsOPGSupport = 0
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
	AND	aa.BR_PIEPCCC IN (@rpPIEPCCC)
	AND	aa.Snapshot_Period = 'Live'
	AND	aa.Activity_Type IN ('TT_Task','TT_LOE')

LEFT JOIN #l2l3_d l2aa
	ON	aa.BR_L2WorkPackage = l2aa.BR_L2WorkPackage
	AND	aa.Snapshot_Date = l2aa.Snapshot_Date

WHERE 
	rtp.BR_Resource_Type = 'RT_Labor'
AND	rtp.Snapshot_Period = 'Live'

GROUP BY
	aa.BR_ProjectNumber
,	ISNULL(l2aa.Activity_ID,aa.BR_ProjectNumber+aa.BR_PIEPCCC+'xxxx')
,	ISNULL(l2aa.Activity_Name,'Not Available')
,	rtp.BR_WorkWeek
,	aa.BR_PIEPCCC

/* ******************************************************************************************** */
-->> EARNED
/* ******************************************************************************************** */
-->> List of Snapshot Dates and the Snapshot date previous to it.

SELECT 
	DATEADD(dd,1,@rpPeriod) as Snapshot_Date
,	@rpLastPeriod AS Snapshot_Date_Last
INTO #cl_d

CREATE INDEX idx_#cld ON #cl_d (Snapshot_Date)

-->> List of Work Packages

SELECT
	aa.Snapshot_Date
,	aa.Activity_Key
,	aa.Activity_ID
,	aa.Activity_Name
,	aa.Project_ID
,	aa.Activity_ID+' - '+aa.Activity_Name as Workpackage
,	aa.BR_ProjectNumber as ProjectNumber
,	aa.Project_Key
,	aa.BR_Percent_Complete as Percent_Complete
,	aa.BR_PIEPCCC as PIEPCCC
,	aa.ApprBL_Budgeted_Labor_Units as Budgeted_Labor_Units
INTO #aa_d
FROM NPDW_Report.sabi.v_fact_0210c_ActivityL2_Weekly aa

WHERE
	aa.Snapshot_Date = @rpLastPeriod
AND	aa.BR_CM_ACTIVITY_LEVEL_Val = '2'
AND	aa.Activity_Type = 'TT_WBS'
AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
AND	aa.BR_ProjectNumber IN (@rpProject)
AND	aa.BR_PIEPCCC IN (@rpPIEPCCC)

UNION ALL

SELECT
	aa.Snapshot_Date
,	aa.Activity_Key
,	aa.Activity_ID
,	aa.Activity_Name
,	aa.Project_ID
,	aa.Activity_ID+' - '+aa.Activity_Name as Workpackage
,	aa.BR_ProjectNumber as ProjectNumber
,	aa.Project_Key
,	aa.BR_Percent_Complete as Percent_Complete
,	aa.BR_PIEPCCC as PIEPCCC
,	CASE 
	WHEN @rpBaselineType = 'Approved' THEN aa.ApprBL_Budgeted_Labor_Units 
	WHEN @rpBaselineType = 'Recovery' THEN aa.RecBL_Budgeted_Labor_Units
	WHEN @rpBaselineType = 'Original' THEN aa.OrigBL_Budgeted_Labor_Units
	END as Budgeted_Labor_Units

FROM NPDW_Report.sabi.v_fact_0200c_ActivityL2_Daily aa
WHERE
	aa.Snapshot_Period = 'Live'
AND	aa.BR_CM_ACTIVITY_LEVEL_Val = '2'
AND	aa.Activity_Type = 'TT_WBS'
AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
AND	aa.BR_ProjectNumber IN (@rpProject)
AND	aa.BR_PIEPCCC IN (@rpPIEPCCC)

CREATE INDEX idx_#aad ON #aa_d (Activity_Key, Snapshot_Date)

SELECT
	COALESCE(aa.Snapshot_Date,cs.Snapshot_Date) as Snapshot_Date
,	COALESCE(aa.Activity_ID,bb.Activity_ID) as Activity_ID
,	COALESCE(aa.Activity_Name,bb.Activity_Name) as Activity_Name
,	COALESCE(aa.PIEPCCC,bb.PIEPCCC) as PIEPCCC
,	COALESCE(aa.ProjectNumber,bb.ProjectNumber) as ProjectNumber
,	ISNULL(aa.Budgeted_Labor_Units,0)*ISNULL(aa.Percent_Complete,0)/100 as Earned_LTD
,	ISNULL(bb.Budgeted_Labor_Units,0)*ISNULL(bb.Percent_Complete,0)/100 as Earned_Last_LTD

INTO #v_d
FROM #aa_d aa

LEFT JOIN #cl_d cl
	ON	cl.Snapshot_Date = aa.Snapshot_Date

FULL OUTER JOIN #aa_d bb
	ON	bb.Snapshot_Date = cl.Snapshot_Date_Last
	AND	aa.Activity_Key = bb.Activity_Key

LEFT JOIN #cl_d cs
	ON	bb.Snapshot_Date = cs.Snapshot_Date_Last

WHERE
	COALESCE(aa.Snapshot_Date,cs.Snapshot_Date) IS NOT NULL

INSERT INTO #tt_d
SELECT
	a.ProjectNumber
,	a.Activity_ID
,	a.Activity_Name
,	a.PIEPCCC
,	dd.WorkWeek
,	SUM(a.Earned_LTD - a.Earned_Last_LTD)
,	SUM(a.Earned_LTD)
,	'Earned'
FROM #v_d a

LEFT JOIN NPDW_Report.sabi.v_dim_0254_TimePhasePeriod dd ON dd.Date = a.Snapshot_Date

GROUP BY
	a.ProjectNumber
,	a.Activity_ID
,	a.Activity_Name
,	dd.WorkWeek
,	a.PIEPCCC

/* ******************************************************************************************** */
-->> OUTPUT FROM MASTER TABLE
/* ******************************************************************************************** */


SELECT 
   t.[ProjectNumber]
  ,mpl.BundleTitleLong
  ,mpl.ProgramWBS
  ,mpl.ProjectTitleCombined
  ,mpl.VendorDescription
  ,t.[Activity_ID]
  ,t.[Activity_Name]
  ,t.PIEPCCC
  ,mpl.Grouping

  ,SUM(CASE WHEN [Type] = 'Planned'  AND [WorkWeek] > @rpLastPeriodWeek AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [Week_PV]
  ,SUM(CASE WHEN [Type] = 'Forecast' AND [WorkWeek] > @rpLastPeriodWeek AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [Week_FC]
  ,SUM(CASE WHEN [Type] = 'Earned'   AND [WorkWeek] > @rpLastPeriodWeek AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [Week_EV]
  ,SUM(CASE WHEN [Type] = 'Actual'   AND [WorkWeek] > @rpLastPeriodWeek AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [Week_AV]
  ,SUM(CASE WHEN [Type] = 'Actual'   AND [WorkWeek] > @rpLast2PeriodWeek AND [WorkWeek] <= @rpLastPeriodWeek THEN [Hours] ELSE 0 END) AS [Week_AVLast]

  ,SUM(CASE WHEN [Type] = 'Forecast Last L3' AND [WorkWeek] > @rpLastPeriodWeek AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [Week_FC3]
  ,SUM(CASE WHEN [Type] = 'Planned'  AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [LTD_PV]
  ,SUM(CASE WHEN [Type] = 'Forecast' AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [LTD_FC]
  ,SUM(CASE WHEN [Type] = 'Earned'   AND [WorkWeek] = @rpPeriodWeek THEN [HoursLTD] ELSE 0 END) AS [LTD_EV]
  ,SUM(CASE WHEN [Type] = 'Actual'   AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [LTD_AV]
  ,SUM(CASE WHEN [Type] = 'Actual'   AND [WorkWeek] <= @rpLastPeriodWeek THEN [Hours] ELSE 0 END) AS [LTD_AVLast]

  ,SUM(CASE WHEN [Type] = 'Forecast L3' AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [LTD_FC3]
  ,SUM(CASE WHEN [Type] = 'Planned'  THEN [Hours] ELSE 0 END) AS [LC_PV]
  ,SUM(CASE WHEN [Type] = 'Forecast' THEN [Hours] ELSE 0 END) AS [LC_FC]
  ,SUM(CASE WHEN [Type] = 'Forecast Last' THEN [Hours] ELSE 0 END) AS [LC_FCLast]
  ,SUM(CASE WHEN [Type] = 'Earned'   THEN [Hours] ELSE 0 END) AS [LC_EV] 
  ,SUM(CASE WHEN [Type] = 'Forecast L3' THEN [Hours] ELSE 0 END) AS [LC_FC3]
  ,SUM(CASE WHEN [Type] = 'Remaining' THEN [Hours] ELSE 0 END) AS [LC_RV]
  ,SUM(CASE WHEN [Type] = 'Remaining Last' THEN [Hours] ELSE 0 END) AS [LC_RVLast]
  ,SUM(CASE WHEN [Type] = 'Budget' THEN [Hours] ELSE 0 END) AS [LC_BV]
  ,SUM(CASE WHEN [Type] = 'Target' THEN [Hours] ELSE 0 END) AS [LC_TV]
  ,SUM(CASE WHEN [Type] = 'Forecast burned rate' THEN [Hours] ELSE 0 END) AS [Burn]
,  max(aa.Finish) as finish
FROM #tt_d t

LEFT JOIN ( select

   mpl.BundleTitleLong
  ,mpl.ProjectNumber
  ,mpl.IsCurrent
  ,mpl.ProgramWBS
  ,mpl.ProjectNumber+' - '+mpl.ProjectTitleLong as ProjectTitleCombined
  ,mpl.VendorDescription
,	CASE
	WHEN @rpGroup = 'Project' THEN mpl.ProjectTitleLong
	WHEN @rpGroup = 'Bundle' THEN mpl.BundleTitleLong
	WHEN @rpGroup = 'Vendor' THEN mpl.VendorDescription
	WHEN @rpGroup = 'Strat III' THEN 'Strat III: '+ISNULL(mpl.ProjectAttribute_STRATUM_III,'Not Available')
	WHEN @rpGroup = 'Strat IV' THEN 'Strat IV: '+ISNULL(mpl.ProjectAttribute_STRATUM_IV,'Not Available')
	ELSE 'N/A'
	END as Grouping

from NPDW.idbnp_rpt.v_dim_projectmasterextended mpl
	where	mpl.IsCurrent = 1
) mpl
        ON	mpl.ProjectNumber = t.ProjectNumber

left join NPDW_Report.sabi.v_fact_0200c_ActivityL2_Daily aa
	ON	aa.Activity_ID = t.Activity_ID
	AND	aa.BR_ProjectNumber = t.ProjectNumber
--	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	aa.Snapshot_Period = 'Live'

GROUP BY
   t.[ProjectNumber]
  ,mpl.BundleTitleLong
  ,mpl.ProgramWBS
  ,mpl.ProjectTitleCombined
  ,mpl.VendorDescription
  ,t.[Activity_ID]
  ,t.[Activity_Name]
  ,t.PIEPCCC
  ,mpl.Grouping
  --,aa.Finish
  order by Week_AV,LC_RV DESC


END
ELSE

BEGIN
IF OBJECT_ID('tempdb..#L2LOE') 	IS NOT NULL DROP TABLE #L2LOE
IF OBJECT_ID('tempdb..#l2l3') 	IS NOT NULL DROP TABLE #l2l3
IF OBJECT_ID('tempdb..#pb') 	IS NOT NULL DROP TABLE #pb
IF OBJECT_ID('tempdb..#cl') 	IS NOT NULL DROP TABLE #cl
IF OBJECT_ID('tempdb..#aa') 	IS NOT NULL DROP TABLE #aa
IF OBJECT_ID('tempdb..#dd') 	IS NOT NULL DROP TABLE #dd
IF OBJECT_ID('tempdb..#v')  	IS NOT NULL DROP TABLE #v	-- Earned
IF OBJECT_ID('tempdb..#tt') 	IS NOT NULL DROP TABLE #tt	-- MASTER TABLE | Planned | Forecast | Earned 
-->> There is a possibility that multiple work packages will have the same BR_L2WorkPackage coding. To ensure that level 3 activities are not duplicated when matching we use this logic to identify only a single work package for each BR_L2WorkPackage

; WITH a as
(
SELECT 
	aa.Snapshot_Date
,	aa.BR_L2WorkPackage
,	aa.Activity_ID
,	aa.Activity_Name
,	aa.Activity_ID+' - '+aa.Activity_Name as WorkPackage
,	aa.BR_NR_LOE_WORK_Val
,	ROW_NUMBER() OVER (PARTITION BY aa.Snapshot_Date, aa.BR_L2WorkPackage ORDER BY aa.BR_NR_LOE_WORK_Val DESC, aa.Activity_ID) as rn

FROM NPDW_Report.sabi.v_fact_0210c_ActivityL2_Weekly aa

WHERE
	( aa.Snapshot_Date = @rpPeriod OR aa.Snapshot_Date = @rpLastPeriod )
AND	aa.BR_ProjectNumber IN (@rpProject)
)
SELECT a.* INTO #l2l3 FROM a WHERE a.rn = 1

CREATE INDEX idx_#l2l3 ON #l2l3 (Snapshot_Date, BR_L2WorkPackage)


-->> We use this table to select the right baseline for our planned tables.
; WITH a as
(
SELECT DISTINCT
	pb.Project_ID
,	pb.BL_Project_ID
,	pb.BaselineType

FROM NPDW_Report.sabi.v_fact_0212f_ResourceTimePhase_BL_Weekly pb

WHERE
	pb.Snapshot_Date= @rpPeriod
)

SELECT 
	pb.Project_ID
,	pb.BaselineType
,	ROW_NUMBER() OVER (PARTITION BY pb.Project_ID ORDER BY pb.BaselineType DESC) as rn
INTO #pb
FROM a pb

WHERE
	pb.BaselineType = @rpBaselineType
OR	pb.BaselineType = CASE WHEN @rpBaselineType = 'Recovery' THEN 'Approved' ELSE 'Homer' END

DELETE FROM #pb WHERE rn <> 1


CREATE INDEX idx_#pb ON #pb (Project_ID, BaselineType)


-->> Creating the summary table into which we'll dump our data
CREATE TABLE #tt (
   [ProjectNumber]	VARCHAR(30)
  ,[Activity_ID]	VARCHAR(30)
  ,[Activity_Name]	VARCHAR(255)
  ,[PIEPCCC]		VARCHAR(10)
  ,[WorkWeek]		VARCHAR(10)
  ,[Hours]		DECIMAL(19,6)
  ,[HoursLTD]		DECIMAL(19,6)
  ,[Type]		VARCHAR(20)
)


/*------------------------------------------------------------------------------------------------*/
-->> PLANNED / BASELINE
/*------------------------------------------------------------------------------------------------*/

INSERT INTO #tt
SELECT
	aa.BR_ProjectNumber as ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
,	aa.BR_PIEPCCC
,	rtp.BR_WorkWeek as WorkWeek
,	SUM(rtp.Planned_Hours) as Forecast_Hours
,	0
,	'Planned'

FROM NPDW_Report.sabi.v_fact_0212f_ResourceTimePhase_BL_Weekly rtp

INNER JOIN NPDW_Report.sabi.v_fact_0210c_ActivityL2_Weekly aa
	ON	aa.Activity_Key = rtp.Activity_Key
	AND	aa.BR_CM_ACTIVITY_LEVEL_Val = '2'
	AND	aa.Activity_Type = 'TT_WBS'
	AND	aa.Snapshot_Date = @rpPeriod
	AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
	AND	aa.BR_PIEPCCC IN (@rpPIEPCCC)
	AND	aa.BR_ProjectNumber IN (@rpProject)

INNER JOIN #pb pb
	ON	pb.Project_ID = rtp.Project_ID
	AND	pb.BaselineType = rtp.BaselineType

WHERE
	rtp.Snapshot_Date = @rpPeriod
AND	rtp.BR_Resource_Type = 'RT_Labor'

GROUP BY
	aa.BR_ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
,	rtp.BR_WorkWeek
,	aa.BR_PIEPCCC

/*------------------------------------------------------------------------------------------------*/
-->> APPROVED BASELINE
/*------------------------------------------------------------------------------------------------*/

INSERT INTO #tt 
SELECT
	aa.BR_ProjectNumber as ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
,	aa.BR_PIEPCCC
,	rtp.BR_WorkWeek as WorkWeek
,	SUM(rtp.Planned_Hours)
,	0
,	'Budget'

FROM NPDW_Report.sabi.v_fact_0212f_ResourceTimePhase_BL_Weekly rtp

INNER JOIN NPDW_Report.sabi.v_fact_0210c_ActivityL2_Weekly aa
	ON	aa.Activity_Key = rtp.Activity_Key
	AND	aa.BR_CM_ACTIVITY_LEVEL_Val = '2'
	AND	aa.Activity_Type = 'TT_WBS'
	AND	aa.Snapshot_Date = @rpPeriod
	AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
	AND	aa.BR_PIEPCCC IN (@rpPIEPCCC)
	AND	aa.BR_ProjectNumber IN (@rpProject)

WHERE
	rtp.Snapshot_Date = @rpPeriod
AND	rtp.BR_Resource_Type = 'RT_Labor'
AND	rtp.BaselineType = 'Approved'

GROUP BY
	aa.BR_ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
,	rtp.BR_WorkWeek
,	aa.BR_PIEPCCC

/* ******************************************************************************************** */
-->> ACTUALS
/* ******************************************************************************************** */

INSERT INTO #tt 
SELECT
	aa.BR_ProjectNumber
,	aa.Activity_ID
,   	aa.Activity_Name
,	aa.BR_PIEPCCC
,	tpp.WorkWeek
,	SUM(inv.Total_Hours)
,	0
,	'Actual'

FROM #inv inv

INNER JOIN  #wbs wbs
	ON	wbs.line_code =inv.alter_cost_c1_ 

INNER JOIN NPDW_Report.sabi.v_fact_0210c_ActivityL2_Weekly aa
	ON	aa.Activity_ID = wbs.wp
	AND	aa.BR_ProjectNumber = wbs.project_no
	AND	aa.Snapshot_Date = @rpPeriod
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	aa.BR_PIEPCCC IN (@rpPIEPCCC)

INNER JOIN NPDW_Report.sabi.v_dim_0254_TimePhasePeriod tpp
	ON	tpp.Date = inv.week_ending

WHERE
	inv.week_ending <= @rpPeriod

GROUP BY
	aa.BR_ProjectNumber
,	aa.Activity_ID
,   	aa.Activity_Name
,	tpp.WorkWeek
,	aa.BR_PIEPCCC

INSERT INTO #tt
SELECT
	ah.Project as ProjectNumber
,	ah.project+ah.wbs as Activity_ID
,	ISNULL(aa.Activity_Name,'Not Available') as Activity_Name
,	aa.BR_PIEPCCC
,	tpp.WorkWeek as WorkWeek
,	SUM(ah.Hours) as Hours
,	0 as HoursLTD
,	'Actual' as Type

FROM NPDW_Report.ebx.v_AH_TF_0100_ACTUAL_HOUR_Live ah

INNER JOIN NPDW_Report.sabi.v_fact_0210c_ActivityL2_Weekly aa
	ON	aa.Activity_ID = ah.project+ah.wbs
	AND	aa.Snapshot_Date = @rpPeriod

INNER JOIN NPDW_Report.sabi.v_dim_0252_ProjectMaster a
	ON	a.ProjectNumber = ah.Project
	AND	a.ProjectNumber IN (@rpProject)

INNER JOIN NPDW_Report.sabi.v_dim_0254_TimePhasePeriod tpp
	ON	tpp.Date = ah.date00
	AND	tpp.Date <= @rpPeriod

WHERE
	LEFT(ah.WBS,1) IN (@rpPIEPCCC)
AND	a.ProjectNumber NOT IN (SELECT tt.ProjectNumber FROM #tt tt WHERE tt.Type = 'Actual')

GROUP BY
	ah.Project
,	ah.wbs
,	aa.Activity_Name
,	tpp.WorkWeek
,	aa.BR_PIEPCCC

INSERT INTO #tt
SELECT 
	ft.Project as ProjectNumber
,	ft.WorkPackage as Activity_ID
,	ISNULL(aa.Activity_Name,'Not Available') as Activity_Name
,	aa.BR_PIEPCCC
,	fw.WorkWeek
,	SUM(ft.HoursQuantity) as Hours
,	0 as HoursLTD
,	'Actual' as Type

FROM NPDW.dbo.v_fact_FinTransaction ft

INNER JOIN NPDW.dbo.v_dim_FinSourceSystem fss
	ON	fss.FinSourceSystem_Key = ft.FinSourceSystem_FKey
	AND	fss.FinSourceSystemDesc = 'Tempus'

LEFT JOIN NPDW_Report.sabi.v_fact_0210c_ActivityL2_Weekly aa
	ON	aa.Activity_ID = ft.WorkPackage
	AND	aa.BR_ProjectNumber = ft.Project
	AND	aa.Snapshot_Date = @rpPeriod

INNER JOIN #fw fw
	ON	fw.FiscalWeek = ft.FiscalWeek

INNER JOIN NPDW_Report.sabi.v_dim_0252_ProjectMaster a
	ON	a.ProjectNumber = ft.Project
	AND	a.ProjectNumber IN (@rpProject)
	AND	a.ProjectNumber NOT IN (SELECT DISTINCT ah.Project FROM NPDW_Report.ebx.v_AH_TF_0100_ACTUAL_HOUR_Live ah)
	AND	a.ProjectNumber NOT IN (SELECT DISTINCT ISNULL(wbs.project_no,'N/A') FROM #wbs wbs)

WHERE
	LEFT(ft.Local,1) IN (@rpPIEPCCC)
AND	fw.WorkWeek <= @rpPeriodWeek

GROUP BY
	ft.Project
,	ft.WorkPackage
,	aa.Activity_Name
,	fw.WorkWeek
,	aa.BR_PIEPCCC

INSERT INTO #tt
SELECT		
	onc.Project	as ProjectNumber
,	onc.Project+onc.WBS as Activity_ID
,	ISNULL(aa.Activity_Name,'Not Available') as Activity_Name
,	aa.BR_PIEPCCC
,	tpp.WorkWeek
,	SUM(onc.Hrs) as Hours
,	0 as HoursLTD
,	'Actual' as Type

FROM NPDW_Report.onc.v_fact_0311a_OncoreDetails_Daily	onc

LEFT JOIN NPDW_Report.sabi.v_fact_0210c_ActivityL2_Weekly aa
	ON	aa.Activity_ID = onc.Project+onc.WBS
	AND	aa.BR_ProjectNumber = onc.Project
	AND	aa.Snapshot_Date = @rpPeriod
		
INNER JOIN NPDW_Report.sabi.v_dim_0254_TimePhasePeriod tpp		
	ON	tpp.Date = onc.TS_Date

INNER JOIN NPDW_Report.sabi.v_dim_0252_ProjectMaster a
	ON	a.ProjectNumber = onc.Project
	AND	a.ProjectNumber IN (@rpProject)
	AND	a.ProjectNumber NOT IN (SELECT DISTINCT ah.Project FROM NPDW_Report.ebx.v_AH_TF_0100_ACTUAL_HOUR_Live ah)
	AND	a.ProjectNumber NOT IN (SELECT DISTINCT ISNULL(wbs.project_no,'N/A') FROM #wbs wbs)
		
WHERE		
	LEFT(onc.WBS,1) IN (@rpPIEPCCC)
AND	onc.Approval_Status IN ('APPROVED','NEGATED','PENDING')	
AND	tpp.WorkWeek <= @rpPeriodWeek		

GROUP BY
	onc.Project
,	onc.WBS
,	aa.Activity_Name
,	tpp.WorkWeek
,	aa.BR_PIEPCCC

/*******************************************************/
-->> FORECAST L2
/*******************************************************/

INSERT INTO #tt
SELECT
	aa.BR_ProjectNumber as ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
,	aa.BR_PIEPCCC
,	rtp.BR_WorkWeek as WorkWeek
,	SUM(rtp.Planned_Hours) as Hours
,	0
,	'Forecast'

FROM NPDW_Report.sabi.v_fact_0212a_ResourceTimePhase_Weekly rtp

INNER JOIN NPDW_Report.sabi.v_fact_0210c_ActivityL2_Weekly aa
	ON	aa.Activity_Key = rtp.Activity_Key
	AND	aa.BR_CM_ACTIVITY_LEVEL_Val = '2'
	AND	aa.Activity_Type = 'TT_WBS'
	AND	aa.Snapshot_Date = @rpPeriod
	AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	aa.BR_PIEPCCC IN (@rpPIEPCCC)

WHERE
	rtp.Snapshot_Date = @rpPeriod
AND	rtp.BR_Resource_Type = 'RT_Labor'

GROUP BY
	aa.BR_ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
,	rtp.BR_WorkWeek
,	aa.BR_PIEPCCC

/*******************************************************/
-->> FORECAST L2 LAST
/*******************************************************/

INSERT INTO #tt
SELECT
	aa.BR_ProjectNumber as ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
,	aa.BR_PIEPCCC
,	rtp.BR_WorkWeek as WorkWeek
,	SUM(rtp.Planned_Hours) as Hours
,	0
,	'Forecast Last'

FROM NPDW_Report.sabi.v_fact_0212a_ResourceTimePhase_Weekly rtp

INNER JOIN NPDW_Report.sabi.v_fact_0210c_ActivityL2_Weekly aa
	ON	aa.Activity_Key = rtp.Activity_Key
	AND	aa.BR_CM_ACTIVITY_LEVEL_Val = '2'
	AND	aa.Activity_Type = 'TT_WBS'
	AND	aa.Snapshot_Date = @rpLastPeriod
	AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	aa.BR_PIEPCCC IN (@rpPIEPCCC)

WHERE
	rtp.Snapshot_Date = @rpLastPeriod
AND	rtp.BR_Resource_Type = 'RT_Labor'

GROUP BY
	aa.BR_ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
,	rtp.BR_WorkWeek
,	aa.BR_PIEPCCC


/*******************************************************/
-->> Forecast burned rate
/*******************************************************/

INSERT INTO #tt
SELECT
	aa.BR_ProjectNumber as ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
,	aa.BR_PIEPCCC
,	'2019WW01' as WorkWeek
,	SUM(rtp.Planned_Hours)/count(distinct(rtp.BR_WorkWeek)) as Hours
,	0
,	'Forecast burned rate'

FROM NPDW_Report.sabi.v_fact_0212a_ResourceTimePhase_Weekly rtp

INNER JOIN NPDW_Report.sabi.v_fact_0210c_ActivityL2_Weekly aa
	ON	aa.Activity_Key = rtp.Activity_Key
	AND	aa.BR_CM_ACTIVITY_LEVEL_Val = '2'
	AND	aa.Activity_Type = 'TT_WBS'
	AND	aa.Snapshot_Date = @rpPeriod
	AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	aa.BR_PIEPCCC IN (@rpPIEPCCC)

WHERE
	rtp.Snapshot_Date = @rpPeriod
AND	rtp.BR_Resource_Type = 'RT_Labor'

GROUP BY
	aa.BR_ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
--,	rtp.BR_WorkWeek
,	aa.BR_PIEPCCC

union all

SELECT
	aa.BR_ProjectNumber as ProjectNumber
,	'dummy' as Activity_ID
,	'dummy' as Activity_Name
,	aa.BR_PIEPCCC
,	'2019WW01' as WorkWeek
,	SUM(rtp.Planned_Hours)/count(distinct(rtp.BR_WorkWeek)) as Hours
,	0
,	'Forecast burned rate'

FROM NPDW_Report.sabi.v_fact_0212a_ResourceTimePhase_Weekly rtp

INNER JOIN NPDW_Report.sabi.v_fact_0210c_ActivityL2_Weekly aa
	ON	aa.Activity_Key = rtp.Activity_Key
	AND	aa.BR_CM_ACTIVITY_LEVEL_Val = '2'
	AND	aa.Activity_Type = 'TT_WBS'
	AND	aa.Snapshot_Date = @rpPeriod
	AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	aa.BR_PIEPCCC IN (@rpPIEPCCC)

WHERE
	rtp.Snapshot_Date = @rpPeriod
AND	rtp.BR_Resource_Type = 'RT_Labor'

GROUP BY
	aa.BR_ProjectNumber
--,	rtp.BR_WorkWeek
,	aa.BR_PIEPCCC

/*******************************************************/
-->> Remaining L2
/*******************************************************/

INSERT INTO #tt
SELECT
	aa.BR_ProjectNumber as ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
,	aa.BR_PIEPCCC
,	rtp.BR_WorkWeek as WorkWeek
,	SUM(rtp.Remaining_Hours) as Hours
,	0
,	'Remaining'

FROM NPDW_Report.sabi.v_fact_0212a_ResourceTimePhase_Weekly rtp

INNER JOIN NPDW_Report.sabi.v_fact_0210c_ActivityL2_Weekly aa
	ON	aa.Activity_Key = rtp.Activity_Key
	AND	aa.Snapshot_Date = @rpPeriod
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	aa.BR_CM_ACTIVITY_LEVEL_Val = '2'
	AND	aa.Activity_Type = 'TT_WBS'
	AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
	AND	aa.BR_PIEPCCC IN (@rpPIEPCCC)

WHERE
	rtp.Snapshot_Date = @rpPeriod
AND	rtp.BR_Resource_Type = 'RT_Labor'

GROUP BY
	aa.BR_ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
,	rtp.BR_WorkWeek
,	aa.BR_PIEPCCC

INSERT INTO #tt 
SELECT
	aa.BR_ProjectNumber as ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
,	aa.BR_PIEPCCC
,	rtp.BR_WorkWeek as WorkWeek
,	SUM(rtp.Remaining_Hours) as Hours
,	0
,	'Remaining Last'

FROM NPDW_Report.sabi.v_fact_0212a_ResourceTimePhase_Weekly rtp

INNER JOIN NPDW_Report.sabi.v_fact_0210c_ActivityL2_Weekly aa
	ON	aa.Activity_Key = rtp.Activity_Key
	AND	aa.BR_CM_ACTIVITY_LEVEL_Val = '2'
	AND	aa.Activity_Type = 'TT_WBS'
	AND	aa.Snapshot_Date = @rpLastPeriod
	AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	aa.BR_PIEPCCC IN (@rpPIEPCCC)

WHERE
	rtp.Snapshot_Date = @rpLastPeriod
AND	rtp.BR_Resource_Type = 'RT_Labor'

GROUP BY
	aa.BR_ProjectNumber
,	aa.Activity_ID
,	aa.Activity_Name
,	rtp.BR_WorkWeek
,	aa.BR_PIEPCCC

/* ******************************************************************************************** */
-->> FORECAST LEVEL 3
/* ******************************************************************************************** */

INSERT INTO #tt
SELECT
	aa.BR_ProjectNumber as ProjectNumber
,	ISNULL(l2aa.Activity_ID,aa.BR_ProjectNumber+aa.BR_PIEPCCC+'xxxx') as Activity_ID
,	ISNULL(l2aa.Activity_Name,'Not Available') as Activity_Name
,	aa.BR_PIEPCCC
,	rtp.BR_WorkWeek as WorkWeek
,	SUM(rtp.Planned_Hours)
,	0
,	'Forecast L3'

FROM 	NPDW_Report.sabi.v_fact_0212a_ResourceTimePhase_Weekly rtp

INNER JOIN NPDW_Report.sabi.v_fact_0210d_ActivityL3_Weekly aa
	ON	aa.Activity_Key = rtp.Activity_Key
	AND	aa.Snapshot_Date = rtp.Snapshot_Date
	AND	aa.BR_IsOPGSupport = 0
	AND	aa.BR_ProjectNumber IN (@rpProject)
	AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
	AND	aa.BR_PIEPCCC IN (@rpPIEPCCC)
	AND	aa.Snapshot_Date = @rpPeriod
	AND	aa.Activity_Type IN ('TT_Task','TT_LOE')

LEFT JOIN #l2l3 l2aa
	ON	aa.BR_L2WorkPackage = l2aa.BR_L2WorkPackage
	AND	aa.Snapshot_Date = l2aa.Snapshot_Date
	AND	l2aa.Snapshot_Date = @rpPeriod

WHERE
	rtp.BR_Resource_Type = 'RT_Labor'
AND	rtp.Snapshot_Date = @rpPeriod

GROUP BY
	aa.BR_ProjectNumber
,	ISNULL(l2aa.Activity_ID,aa.BR_ProjectNumber+aa.BR_PIEPCCC+'xxxx')
,	ISNULL(l2aa.Activity_Name,'Not Available')
,	rtp.BR_WorkWeek
,	aa.BR_PIEPCCC

/* ******************************************************************************************** */
-->> EARNED
/* ******************************************************************************************** */
-->> List of Snapshot Dates and the Snapshot date previous to it.
SELECT DISTINCT
	@rpPeriod as Snapshot_Date
,	@rpLastPeriod as Snapshot_Date_Last
INTO #cl

CREATE INDEX idx_#cl ON #cl (Snapshot_Date)

-->> List of Work Packages

SELECT
	aa.Snapshot_Date
,	aa.Activity_Key
,	aa.Activity_ID
,	aa.Activity_Name
,	aa.Project_ID
,	aa.Activity_ID+' - '+aa.Activity_Name as Workpackage
,	aa.BR_ProjectNumber as ProjectNumber
,	aa.Project_Key
,	aa.BR_Percent_Complete as Percent_Complete
,	aa.BR_PIEPCCC as PIEPCCC
,	aa.ApprBL_Budgeted_Labor_Units as Budgeted_Labor_Units
INTO #aa
FROM NPDW_Report.sabi.v_fact_0210c_ActivityL2_Weekly aa

WHERE
	( aa.Snapshot_Date = @rpPeriod OR aa.Snapshot_Date = @rpLastPeriod )
AND	aa.BR_CM_ACTIVITY_LEVEL_Val = '2'
AND	aa.Activity_Type = 'TT_WBS'
AND	RIGHT(aa.BR_NR_EXECUTION_WINDOWS_Val,1) <> 'C'
AND	aa.BR_ProjectNumber IN (@rpProject)
AND	aa.BR_PIEPCCC IN (@rpPIEPCCC)

CREATE INDEX idx_#aa ON #aa (Activity_Key, Snapshot_Date)

SELECT
	COALESCE(aa.Snapshot_Date,cs.Snapshot_Date) as Snapshot_Date
,	COALESCE(aa.Activity_ID,bb.Activity_ID) as Activity_ID
,	COALESCE(aa.Activity_Name,bb.Activity_Name) as Activity_Name
,	COALESCE(aa.PIEPCCC,bb.PIEPCCC) as PIEPCCC
,	COALESCE(aa.ProjectNumber,bb.ProjectNumber) as ProjectNumber
,	ISNULL(aa.Budgeted_Labor_Units,0)*ISNULL(aa.Percent_Complete,0)/100 as Earned_LTD
,	ISNULL(bb.Budgeted_Labor_Units,0)*ISNULL(bb.Percent_Complete,0)/100 as Earned_Last_LTD

INTO #v
FROM #aa aa

LEFT JOIN #cl cl
	ON	cl.Snapshot_Date = aa.Snapshot_Date

FULL OUTER JOIN #aa bb
	ON	bb.Snapshot_Date = cl.Snapshot_Date_Last
	AND	aa.Activity_Key = bb.Activity_Key

LEFT JOIN #cl cs
	ON	bb.Snapshot_Date = cs.Snapshot_Date_Last

WHERE
	COALESCE(aa.Snapshot_Date,cs.Snapshot_Date) IS NOT NULL

INSERT INTO #tt
SELECT
	a.ProjectNumber
,	a.Activity_ID
,	a.Activity_Name
,	a.PIEPCCC
,	dd.WorkWeek
,	SUM(a.Earned_LTD - a.Earned_Last_LTD)
,	SUM(a.Earned_LTD)
,	'Earned'
FROM #v a

LEFT JOIN NPDW_Report.sabi.v_dim_0254_TimePhasePeriod dd ON dd.Date = a.Snapshot_Date

GROUP BY
	a.ProjectNumber
,	a.Activity_ID
,	a.Activity_Name
,	dd.WorkWeek
,	a.PIEPCCC

/* ******************************************************************************************** */
-->> OUTPUT FROM MASTER TABLE
/* ******************************************************************************************** */


SELECT 
   t.[ProjectNumber]
  ,mpl.BundleTitleLong
  ,mpl.ProgramWBS
  ,mpl.ProjectTitleCombined
  ,mpl.VendorDescription
  ,t.[Activity_ID]
  ,t.[Activity_Name]
  ,t.[PIEPCCC]
  ,mpl.Grouping

  ,SUM(CASE WHEN [Type] = 'Planned'  AND [WorkWeek] > @rpLastPeriodWeek AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [Week_PV]
  ,SUM(CASE WHEN [Type] = 'Forecast' AND [WorkWeek] > @rpLastPeriodWeek AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [Week_FC]
  ,SUM(CASE WHEN [Type] = 'Earned'   AND [WorkWeek] > @rpLastPeriodWeek AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [Week_EV]
  ,SUM(CASE WHEN [Type] = 'Actual'   AND [WorkWeek] > @rpLastPeriodWeek AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [Week_AV]
  ,SUM(CASE WHEN [Type] = 'Actual'   AND [WorkWeek] > @rpLast2PeriodWeek AND [WorkWeek] <= @rpLastPeriodWeek THEN [Hours] ELSE 0 END) AS [Week_AVLast]
  ,SUM(CASE WHEN [Type] = 'Forecast Last L3' AND [WorkWeek] > @rpLastPeriodWeek AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [Week_FC3]  


  ,SUM(CASE WHEN [Type] = 'Planned'  AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [LTD_PV]
  ,SUM(CASE WHEN [Type] = 'Forecast' AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [LTD_FC]
  ,SUM(CASE WHEN [Type] = 'Earned'   AND [WorkWeek] = @rpPeriodWeek THEN [HoursLTD] ELSE 0 END) AS [LTD_EV]
  ,SUM(CASE WHEN [Type] = 'Forecast L3' AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [LTD_FC3]
  ,SUM(CASE WHEN [Type] = 'Actual'   AND [WorkWeek] <= @rpPeriodWeek THEN [Hours] ELSE 0 END) AS [LTD_AV]
  ,SUM(CASE WHEN [Type] = 'Actual'   AND [WorkWeek] <= @rpLastPeriodWeek THEN [Hours] ELSE 0 END) AS [LTD_AVLast]


  ,SUM(CASE WHEN [Type] = 'Planned'  THEN [Hours] ELSE 0 END) AS [LC_PV]
  ,SUM(CASE WHEN [Type] = 'Forecast' THEN [Hours] ELSE 0 END) AS [LC_FC]
  ,SUM(CASE WHEN [Type] = 'Forecast Last' THEN [Hours] ELSE 0 END) AS [LC_FCLast]
  
  ,SUM(CASE WHEN [Type] = 'Earned'   THEN [Hours] ELSE 0 END) AS [LC_EV] 
  ,SUM(CASE WHEN [Type] = 'Forecast L3' THEN [Hours] ELSE 0 END) AS [LC_FC3]
  ,SUM(CASE WHEN [Type] = 'Remaining' THEN [Hours] ELSE 0 END) AS [LC_RV]
  ,SUM(CASE WHEN [Type] = 'Remaining Last' THEN [Hours] ELSE 0 END) AS [LC_RVLast]

  ,SUM(CASE WHEN [Type] = 'Budget' THEN [Hours] ELSE 0 END) AS [LC_BV]
  ,SUM(CASE WHEN [Type] = 'Target' THEN [Hours] ELSE 0 END) AS [LC_TV]
  ,SUM(CASE WHEN [Type] = 'Forecast burned rate' THEN [Hours] ELSE 0 END) AS [Burn]
  ,max(aa.Finish) as finish
FROM #tt t

LEFT JOIN ( select

   mpl.BundleTitleLong
  ,mpl.ProjectNumber
  ,mpl.IsCurrent
  ,mpl.ProgramWBS
  ,mpl.ProjectNumber+' - '+mpl.ProjectTitleLong as ProjectTitleCombined
  ,mpl.VendorDescription
,	CASE
	WHEN @rpGroup = 'Project' THEN mpl.ProjectTitleLong
	WHEN @rpGroup = 'Bundle' THEN mpl.BundleTitleLong
	WHEN @rpGroup = 'Vendor' THEN mpl.VendorDescription
	WHEN @rpGroup = 'Strat III' THEN 'Strat III: '+ISNULL(mpl.ProjectAttribute_STRATUM_III,'Not Available')
	WHEN @rpGroup = 'Strat IV' THEN 'Strat IV: '+ISNULL(mpl.ProjectAttribute_STRATUM_IV,'Not Available')
	ELSE 'N/A'
	END as Grouping

from NPDW.idbnp_rpt.v_dim_projectmasterextended mpl
	where	mpl.IsCurrent = 1
) mpl
        ON	mpl.ProjectNumber = t.ProjectNumber

left join NPDW_Report.sabi.v_fact_0210c_ActivityL2_Weekly aa
	ON	aa.Activity_ID = t.Activity_ID
	AND	aa.Snapshot_Date = @rpPeriod
	AND	aa.BR_ProjectNumber = t.ProjectNumber
--	AND	aa.BR_ProjectNumber IN (@rpProject)
--left join NPDW_Report.sabi.v_fact_0210a_Activity_Weekly aa
 --     on aa.Snapshot_Date = t.
GROUP BY
   t.[ProjectNumber]
  ,mpl.BundleTitleLong
  ,mpl.ProgramWBS
  ,mpl.ProjectTitleCombined
  ,mpl.VendorDescription
  ,t.[Activity_ID]
  ,t.[Activity_Name]
  ,t.[PIEPCCC]
  ,mpl.Grouping
  order by Week_AV,LC_RV DESC
END