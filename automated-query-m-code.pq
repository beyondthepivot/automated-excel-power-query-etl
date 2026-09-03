let
    Source = Folder.Files("YOUR_SOURCE_FOLDER"),
    #"Filtered Hidden Files1" = Table.SelectRows(Source, each [Attributes]?[Hidden]? <> true),

    #"Invoke Custom Function1" = Table.AddColumn(#"Filtered Hidden Files1", "Transform File", each #"Transform File"([Content])),

    #"Renamed Columns1" = Table.RenameColumns(#"Invoke Custom Function1", {"Name", "Source.Name"}),

    #"Removed Other Columns1" = Table.SelectColumns(#"Renamed Columns1", {"Source.Name", "Transform File"}),

    #"Expanded Table Column1" = Table.ExpandTableColumn(#"Removed Other Columns1", "Transform File", Table.ColumnNames(#"Transform File"(#"Sample File"))),

    #"Promoted Headers" = Table.PromoteHeaders(#"Expanded Table Column1", [PromoteAllScalars=true]),

    #"Changed Type" = Table.TransformColumns(#"Promoted Headers", {{"StartdateTime", each try DateTime.From(_) otherwise null, type nullable datetime}}),

    #"Removed Null Dates" = Table.SelectRows(#"Changed Type", each [StartdateTime] <> null),

    #"Changed Volume Type" = Table.TransformColumnTypes(#"Removed Null Dates", {{"Volume", type number}}),

    #"Rounded Volume" = Table.TransformColumns(#"Changed Volume Type", {{"Volume", each Number.Round(_,3), type number}}),

    #"Removed Duplicates" = Table.Distinct(#"Rounded Volume", {"SeriesId","StartdateTime"}),

    #"Added HalfHour" = Table.AddColumn(#"Removed Duplicates", "HalfHour", 
            each #datetime(Date.Year([StartdateTime]),
                Date.Month([StartdateTime]),
                Date.Day([StartdateTime]),
                Time.Hour([StartdateTime]),
                Number.IntegerDivide(Time.Minute([StartdateTime]),30)*30,0), type datetime),
    
    IntervalCheck = Table.Group( #"Added HalfHour", {"SeriesId"}, {{"MinDiff", each let Times = List.Sort([StartdateTime])
                    in if List.Count(Times) < 2  then 30
                        else Duration.TotalMinutes(Times{1}-Times{0}),
                type number}}),   

FiveMinuteIDTable =
    Table.SelectRows(IntervalCheck, each [MinDiff] = 5),

FiveMinuteSeries =
    Table.Join( #"Added HalfHour", "SeriesId", FiveMinuteIDTable, "SeriesId", JoinKind.Inner),

HalfHourSeries =
    Table.NestedJoin(#"Added HalfHour", {"SeriesId"}, FiveMinuteIDTable, {"SeriesId"},"Match",
    JoinKind.LeftAnti),

    AggregatedFiveMinute =
        Table.Group(FiveMinuteSeries, {"SeriesId","HalfHour"}, {{"Volume", each List.Sum([Volume]), type number}}),

    AggregatedFiveMinuteRenamed =
        Table.RenameColumns(AggregatedFiveMinute, {{"HalfHour","StartdateTime"}}),

    HalfHourSeriesClean =
        Table.SelectColumns(HalfHourSeries, {"SeriesId","StartdateTime","Volume"}),

    Result =
        Table.Combine({HalfHourSeriesClean, AggregatedFiveMinuteRenamed})

in
    Result
