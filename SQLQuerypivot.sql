IF OBJECT_ID('tempdb..#a') IS NOT NULL DROP TABLE #a
IF OBJECT_ID('tempdb..#aa') IS NOT NULL DROP TABLE #aa
DECLARE @startdt DATETIME, @enddt DATETIME, @QueryCol NVARCHAR(MAX)

--get the snapshot tablw with row number

select distinct SNAPSHOT_DATE  INTO #a FROM [eic].[fact_0320a_WBS_Monthly] WBS ORDER BY SNAPSHOT_DATE

select SNAPSHOT_DATE,	ROW_NUMBER() OVER(ORDER BY SNAPSHOT_DATE) AS RowNum  into #aa from #a


SET @startdt = (select SNAPSHOT_DATE from #aa where RowNum  = 1)

SET @enddt = (select SNAPSHOT_DATE from #aa where RowNum  = (select count(SNAPSHOT_DATE) from #aa))


-- use loop to combine the date of columns we need, return as a string 
WHILE @startdt <= @enddt
BEGIN
    SET @QueryCol=isnull(@QueryCol, '')+QUOTENAME(convert(nvarchar(20), @startdt, 101))+(CASE WHEN @startdt<>@enddt THEN ',' ELSE '' END)

	set @startdt = DATEADD(mm,1,CAST(@startdt as Date))
END

--pivot table with the string of the date 

if(ISNULL(@QueryCol, '')<>'')
begin
    set @QueryCol='select ''73113'' as ProjectNumber,'+@QueryCol+' from #aa
                    pivot (avg (RowNum) for 
                    SNAPSHOT_DATE in ('+@QueryCol+')) as finaltable'

    exec (@QueryCol)
end
