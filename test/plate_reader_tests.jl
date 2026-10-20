@testitem "read spectramax" setup=[environment_path] begin
    println("read spectramax")
    data = read_data("inputs/spectramax.xlsx")
    @test data["samples"]["plate_01_a1"]["values"]["abs700"][[1, 2, end - 1, end]] ==
        [0.1493, 0.1623, 0.3297, 0.3629]
    @test data["samples"]["plate_01_e12"]["values"]["abs600"][[1, 2, end - 1, end]] == [
        0.0764, 0.1030, 0.4580, 0.5212]
    wells1 = [string("plate_01_", row, col) for row in 'a':'e', col in 1:12] # Only A-E have data
    wells2 = [string("plate_02_", row, col) for row in 'a':'h', col in 1:12]
    wells = [wells1..., wells2..., "plate_01_time", "plate_01_temperature",
        "plate_02_time", "plate_02_temperature"]  # Flatten to a 1D vector
    @test issetequal(keys(data["samples"]), wells)

    @test issetequal(
        keys(read("inputs/spectramax-data.txt", SpectraMax(); channels=["600", "700"])[1]),
        ["600", "700"])
    @test issetequal(
        keys(read("inputs/spectramax-data2.txt", SpectraMax();
            channels=["530_485_1", "530_485_2", "530_485_3"])[1]),
        ["530_485_1", "530_485_2", "530_485_3"])

    # Missing time point recording in spectramax file
    data, _ = read("inputs/spectramax-missing-timepoint.txt", SpectraMax())
    @test issetequal(keys(data), ["600", "530_485"])
    @test any(ismissing.(data["600"][!, "time"]))
    @test !all(ismissing.(data["600"][!, "time"]))
    @test !any(isnan.(skipmissing(data["600"][!, "time"])))
    @test any(ismissing.(data["600"][!, "temperature"]))
    @test !all(ismissing.(data["600"][!, "temperature"]))
    @test !any(isnan.(skipmissing(data["600"][!, "temperature"])))
    @test any(ismissing.(data["600"][!, "B4"]))
    @test !all(ismissing.(data["600"][!, "B4"]))
    @test !any(isnan.(skipmissing(data["600"][!, "B4"])))
end

@testitem "read biotek" setup=[environment_path] begin
    println("read biotek")
    data = read_data("inputs/biotek.xlsx")
    @test data["samples"]["plate_01_a1"]["values"]["od1"][[1, 2, end - 1, end]] ==
        [0.134, 0.133, 0.131, 0.131]
    @test data["samples"]["plate_01_h12"]["values"]["od2"][[1, 2, end - 1, end]] == [
        0.114, 0.113, 0.577, 0.578]
    @test data["samples"]["plate_01_a2"]["values"]["flu2"][[1, 2, end - 1, end]] == [
        166, 162, 1030, 1024]
    wells = [string("plate_01_", row, col) for row in 'a':'h', col in 1:12]
    wells = [wells..., "plate_01_temperature", "plate_01_time"]  # Flatten to a 1D vector
    @test issetequal(wells, keys(data["samples"]))

    @test issetequal(
        keys(read(
            "inputs/biotek-data.csv", BioTek(); channels=["OD_600"])[1]), ["OD_600"])
end

@testitem "read tecan" setup=[environment_path] begin
    println("read tecan")
    data = read_data("inputs/tecan.xlsx")
    @test issetequal(
        keys(data["samples"]["plate_01_a1"]["values"]), ["OD_600", "OD_700", "GFP"])
    @test data["samples"]["plate_01_a1"]["values"]["OD_600"][[1, 2, end - 1, end]] ==
        convert.(Float32, [0.1378, 0.1437, 0.1451, 0.1453])
    @test data["samples"]["plate_01_h12"]["values"]["GFP"][[1, 2, end - 1, end]] == [
        68, 70, 84, 84]
    wells = [string("plate_01_", row, col) for row in 'a':'h', col in 1:12]
    wells = [wells..., "plate_01_temperature", "plate_01_time"]
    @test issetequal(keys(data["samples"]), wells)

    @test data["samples"]["plate_01_time"]["values"]["OD_600"][[1, 2, end - 1, end]] ==
        [0, 765900, 56622900, 57388100]

    @test issetequal(
        keys(read(
            "inputs/tecan-data.xlsx", Tecan(); channels=["OD_600", "GFP"])[1]),
        ["OD_600", "GFP"])
end

@testitem "read bmg labtech" setup=[environment_path] begin
    println("read bmg labtech")
    data = read_data("inputs/bmg.xlsx")
    @test data["samples"]["plate_01_a1"]["values"]["abs600"][[1, 2, end - 1, end]] ==
        [0.182, 0.185, 0.169, 0.169]
    @test data["samples"]["plate_01_h12"]["values"]["abs700"][[1, 2, end - 1, end]] == [
        0.214, 0.217, 1.123, 1.123]
    @test data["samples"]["plate_01_a2"]["values"]["yfp"][[1, 2, end - 1, end]] == [
        1635, 1613, 2782, 2830]
    wells = [string("plate_01_", row, col) for row in 'a':'h', col in 1:12]
    wells = [wells..., "plate_01_time", "plate_01_temperature"]  # Flatten to a 1D vector
    @test issetequal(keys(data["samples"]), wells)

    @test issetequal(
        keys(read(
            "inputs/bmg-data.csv", BMG(); channels=["ABS_600_0_nm", "FI_YFP_pAN1717"])[1]),
        ["ABS_600_0_nm", "FI_YFP_pAN1717"])
    @test issetequal(
        keys(read("inputs/bmg-data.csv", BMG();
            channels=["ABS_600_0_nm", "ABS_700_0_nm", "FI_YFP_pAN1717"])[1]),
        ["ABS_600_0_nm", "ABS_700_0_nm", "FI_YFP_pAN1717"])
end

@testitem "read plate reader directories" setup=[environment_path] begin
    println("read plate reader directories")
    using Dates

    data = read_data("inputs/example.xlsx")
    @test data["samples"]["plate_01_time"]["values"]["OD"][1:2] ==
        [518000, 1118000]
    @test data["samples"]["plate_01_time"]["values"]["OD"][end] == 67118000
    @test data["samples"]["plate_01_a1"]["values"]["OD"][1:3] == [0.165, 0.167, 0.169]
    @test data["samples"]["plate_01_h12"]["values"]["OD"][end] == 0.148

    @test data["samples"]["plate_01_time"]["values"]["flo"][1:2] == [544714, 1144314]
    @test data["samples"]["plate_01_time"]["values"]["flo"][end] == 67144719
    @test data["samples"]["plate_01_a1"]["values"]["flo"][1:3] == [21, 22, 20]
    @test data["samples"]["plate_01_h12"]["values"]["flo"][end] == 7

    @test issetequal(
        keys(read(
            "inputs/pr_folder", GenericTabular(); channels=["OD"])[1]), ["OD"])
end

@testitem "read pr errors" begin
    @test_throws "Unknown plate reader type: random_string" Longwing.read_multipr_file(
        "anyfile/path", "random_string", ["OD"], Dict())
end

# Test doubling_time
@testitem "doubling_time" begin
    println("doubling_time")
    using DataFrames

    od_df = DataFrame(A=[0.05, 0.1, 0.2, 0.4, 0.8, 1.6, 3.2, 6.4, 12.8, 25.6, 51.2])
    time_col = DataFrame(Time=0:60000:600000)

    @test doubling_time(od_df, time_col, MovingWindow(window_size=3)) ≈
        DataFrame(A=1.0)
    @test doubling_time(
        od_df, time_col, MovingWindow(window_size=3, method=:Endpoints)) ≈
        DataFrame(A=1.0)
    @test doubling_time(
        od_df, time_col, MovingWindow(window_size=3, method=:LinearOnLog)) ≈
        DataFrame(A=1.0)
    @test doubling_time(od_df, time_col, ExpandingWindow(window_size=3)) ≈
        DataFrame(A=1.0)
    @test doubling_time(od_df, time_col, LinearOnLog(start_time=1, end_time=5)) ≈
        DataFrame(A=1.0)
    @test doubling_time(od_df, time_col, Endpoints(start_time=1, end_time=5)) ≈
        DataFrame(A=1.0)
    @test doubling_time(od_df, time_col, FiniteDiff()) ≈ DataFrame(A=1.0)
    @test doubling_time(od_df, time_col, FiniteDiff(type=:onesided)) ≈ DataFrame(A=1.0)
    @test doubling_time(od_df, time_col, SmoothedSpline(order=4.0)) ≈
        DataFrame(A=1.0)

    # Parametric tests
    using Dates
    time_col = DataFrame(:Time => 0:10000:600000)
    # Requires full curve, not just a bit of exponential growth
    f(t) = exp(0.7 / (1 + exp(-2.0 * (t - 5.0))))
    od_df = f.(time_col ./ 60000)
    rename!(od_df, :Time => :A)

    # Check that the actual doubling time is around 1.95
    @test doubling_time(od_df, time_col, FiniteDiff())[1, "A"]≈1.95 atol=0.1

    # Test the parametric methods
    @test doubling_time(od_df, time_col, Logistic())[1, "A"]≈1.95 atol=0.1
    @test doubling_time(od_df, time_col, Gompertz())[1, "A"]≈1.95 atol=0.15
    @test doubling_time(od_df, time_col, ModifiedGompertz())[1, "A"]≈1.95 atol=0.15
    @test doubling_time(od_df, time_col, Richards())[1, "A"]≈1.95 atol=0.1
end

@testitem "growth_rate" begin
    println("growth_rate")
    using DataFrames
    # TODO add tests with more columns and more awkward data
    od_df = DataFrame(A=[0.05, 0.1, 0.2, 0.4, 0.8, 1.6, 3.2, 6.4, 12.8, 25.6, 51.2])
    time_col = DataFrame(Time=0:60000:600000)

    @test growth_rate(od_df, time_col, MovingWindow(window_size=3))[1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, MovingWindow(window_size=3, method=:Endpoints))[
        1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, MovingWindow(window_size=3, method=:LinearOnLog))[
        1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, ExpandingWindow(window_size=3))[1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, LinearOnLog(start_time=1, end_time=5))[
        1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, Endpoints(start_time=1, end_time=5))[
        1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, FiniteDiff())[1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, FiniteDiff(type=:onesided))[1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, SmoothedSpline())[1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, SmoothedSpline(knots=[2, 4, 6, 8]))[1, "A"] ≈ log(2)

    # Recalibrate == :offset
    @test growth_rate(od_df, time_col, FiniteDiff(); recalibrate=:offset)[1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, FiniteDiff(type=:onesided); recalibrate=:offset)[1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, SmoothedSpline(); recalibrate=:offset)[1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, SmoothedSpline(knots=[2, 4, 6, 8]); recalibrate=:offset)[1, "A"] ≈ log(2)

    # Tests for warnings
    od_df_warn = DataFrame(A=[
        0.05, -0.1, -0.2, -0.4, -0.8, -1.6, -3.2, -6.4, -12.8, -25.6, -51.2])
    @test_logs (:warn, r"Not enough data points") match_mode=:any growth_rate(
        od_df_warn, time_col, FiniteDiff(); recalibrate=false)
    @test_logs (:warn, r"Not enough data points") match_mode=:any growth_rate(
        od_df_warn, time_col, LinearOnLog(start_time=1.1, end_time=1.2); recalibrate=false)
    @test_logs (:warn, r"Not enough data points") match_mode=:any growth_rate(
        od_df_warn, time_col, SmoothedSpline(); recalibrate=false)
    @test_logs (:warn, r"Not enough data points") match_mode=:any growth_rate(
        od_df_warn, time_col, Logistic(); recalibrate=false)
    @test_logs (:warn, r"No data points found between start_time") match_mode=:any growth_rate(
        od_df, time_col, LinearOnLog(start_time=-2, end_time=-1); recalibrate=false)

    # Tests for errors
    @test_throws "Unknown finite difference type: unknown" growth_rate(
        od_df, time_col, FiniteDiff(type=:unknown))
    @test_throws "Unknown moving window method: unknown." growth_rate(
        od_df, time_col, MovingWindow(method=:unknown))

    # Parametric tests
    using Dates
    time_col = DataFrame(:Time => 0:10000:600000)
    # Requires full curve, not just a bit of exponential growth
    f(t) = exp(0.7 / (1 + exp(-2.0 * (t - 5.0))))
    od_df = f.(time_col ./ 60000)
    rename!(od_df, :Time => :A)

    # Check that the actual growth rate is around 0.35
    @test growth_rate(od_df, time_col, FiniteDiff())[1, "A"]≈0.35 atol=1e-2

    # Test the parametric methods
    @test growth_rate(od_df, time_col, Logistic())[1, "A"]≈0.35 atol=1e-2
    @test growth_rate(od_df, time_col, Gompertz())[1, "A"]≈0.35 atol=0.025
    @test growth_rate(od_df, time_col, ModifiedGompertz())[1, "A"]≈0.35 atol=0.03
    @test growth_rate(od_df, time_col, Richards())[1, "A"]≈0.35 atol=1e-2
end

@testitem "growth rate - uncertainty" begin
    println("growth rate - uncertainty")
    using DataFrames
    using Measurements
    using Random

    od_df = DataFrame(A=logrange(0.01, 0.4, 21) .+ (rand(Xoshiro(0), 21) .- 0.5) * 0.01,
        B=logrange(0.01, 0.4, 21) .+ (rand(Xoshiro(1), 21) .- 0.5) * 0.01,
        C=logrange(0.01, 0.4, 21) .+ (rand(Xoshiro(2), 21) .- 0.5) * 0.01,
        D=logrange(0.01, 0.4, 21) .+ (rand(Xoshiro(3), 21) .- 0.5) * 0.01,
        E=logrange(0.01, 0.4, 21) .+ (rand(Xoshiro(4), 21) .- 0.5) * 0.01,
        F=logrange(0.01, 0.4, 21))

    time_col = DataFrame(Time=0:60000:1200000)

    exact_gr = growth_rate(od_df, time_col, FiniteDiff())[1, :F]

    function tester(measures)
        pass_accuracy_check = false
        pass_non_nan_check = false
        for measure in measures[1, Not(:F)]
            if !isnan(Measurements.value(measure)) && !isnan(Measurements.uncertainty(measure))
                pass_non_nan_check = true
            end
            @test measure isa Measurement
            @test ! (Measurements.uncertainty(measure) < 0)
            lb = Measurements.value(measure) - 1.96 * Measurements.uncertainty(measure)
            ub = Measurements.value(measure) + 1.96 * Measurements.uncertainty(measure)
            if lb <= exact_gr <= ub
                pass_accuracy_check = true
            end
        end
        if !pass_accuracy_check || !pass_non_nan_check
            @show measures
        end
        @test pass_non_nan_check
        @test pass_accuracy_check
    end

    println("LinearOnLog")
    tester(growth_rate(od_df, time_col, LinearOnLog(start_time=2, end_time=16); uncertainty=true))
    println("ExpandingWindow")
    tester(growth_rate(od_df, time_col, ExpandingWindow(); uncertainty=true))
    println("MovingWindow")
    tester(growth_rate(od_df, time_col, MovingWindow(method=:LinearOnLog); uncertainty=true))
    println("Logistic")
    tester(growth_rate(od_df, time_col, Logistic(lower_limit_flexible=true); uncertainty=true))
    println("Gompertz")
    tester(growth_rate(od_df, time_col, Gompertz(lower_limit_flexible=true); uncertainty=true))
    println("ModifiedGompertz")
    tester(growth_rate(od_df, time_col, ModifiedGompertz(lower_limit_flexible=true); uncertainty=true))
    println("Richards")
    tester(growth_rate(od_df, time_col, Richards(lower_limit_flexible=true); uncertainty=true))
    println("SmoothedSpline")
    tester(growth_rate(od_df, time_col, SmoothedSpline(); uncertainty=true))

    # Test other methods throw an error when uncertainty=true
    @test_throws ArgumentError growth_rate(od_df, time_col, Endpoints(start_time=5, end_time=10); uncertainty=true)
    @test_throws ArgumentError growth_rate(od_df, time_col, MovingWindow(method=:Endpoints); uncertainty=true)
    @test_throws ArgumentError growth_rate(od_df, time_col, FiniteDiff(); uncertainty=true)
end

@testitem "time to max growth" begin
    println("time to max growth")
    using DataFrames
    function f(t)
        if t < 5
            return 0
        elseif t < 15
            return 1 / (1 + exp(-2 * (t - 10)))
        else
            return 1
        end
    end
    t = 0:0.5:20
    r = [
        0.5847079560316877, 0.45840079479217205, -1.2615416418439265, -0.19302484376033796,
        -0.4244814803886498, -0.18088313464643485, -0.5045323424725897,
        -0.5141211372683038, 1.1616201463480844, 1.3296851114162132, -0.43120471016998424,
        1.2613828599505037, -0.4646636774845288, -0.908398391727798, 0.9282112244792343,
        0.15692696269233736, -0.0401373009174321, -0.312658487708534, -0.8446115669549681,
        -0.15644528491336934, 0.22969924085412563, -1.7463816740617624,
        -0.9362537306327118, 1.0494677762330453, -2.21499715347752, 1.0574000162409678,
        -0.2865517812478418, 1.5192666194062108, -0.2152836487775379, -0.621802452401734,
        -1.3307105978023612, 0.29757022692826623, 1.2294126967973198, -0.7646230207734392,
        -0.11071786613263836, -0.022308315590345632, -2.023482208299797,
        -1.433631515044935, -0.1421872400744148, -1.4318637059194546, -0.4371826293473729]
    od = f.(t) + 0.01 * r
    od_df = DataFrame(A=od)
    using Dates
    time_col = DataFrame(Time=t * 60000)

    @test 7 < time_to_max_growth(od_df, time_col, MovingWindow(window_size=5))[1, "A"] <
        10
    @test 7 <
        time_to_max_growth(
            od_df, time_col, MovingWindow(window_size=5, method=:Endpoints))[1, "A"] <
        10
    @test 7 <
        time_to_max_growth(
            od_df, time_col, MovingWindow(window_size=5, method=:LinearOnLog))[
            1, "A"] < 10
    @test 7 <
        time_to_max_growth(
            od_df, time_col, ExpandingWindow(window_size=5))[
            1, "A"] < 10
    @test 7 <
        time_to_max_growth(od_df, time_col, LinearOnLog(start_time=6, end_time=9))[
            1, "A"] < 10
    @test 7 <
        time_to_max_growth(od_df, time_col, Endpoints(start_time=6, end_time=9))[
            1, "A"] < 10
    @test 7 < time_to_max_growth(od_df, time_col, FiniteDiff(); offset=0.01)[1, "A"] < 10
    @test 7 <
        time_to_max_growth(od_df, time_col, FiniteDiff(type=:onesided); offset=0.1)[
            1, "A"] < 10
    @test 7 < time_to_max_growth(od_df, time_col, SmoothedSpline())[1, "A"] < 10
    @test 7 < time_to_max_growth(od_df, time_col, Logistic())[1, "A"] < 10
    @test 7 < time_to_max_growth(od_df, time_col, Gompertz())[1, "A"] < 10
    @test 7 < time_to_max_growth(od_df, time_col, ModifiedGompertz())[1, "A"] < 10
    @test 7 < time_to_max_growth(od_df, time_col, Richards())[1, "A"] < 10

    # Tests for warnings
    od_df_warn = DataFrame(A=[
        0.05, -0.1, -0.2, -0.4, -0.8, -1.6, -3.2, -6.4, -12.8, -25.6, -51.2])
    time_col_warn = DataFrame(:Time => 0:60000:600000)
    @test_logs (:warn, r"Not enough data points") match_mode=:any time_to_max_growth(
        od_df_warn, time_col_warn, FiniteDiff(); recalibrate=false)
    @test_logs (:warn, r"Not enough data points") match_mode=:any time_to_max_growth(
        od_df_warn, time_col_warn, LinearOnLog(start_time=1, end_time=1.5); recalibrate=false)
    @test_logs (:warn, r"Not enough data points") match_mode=:any time_to_max_growth(
        od_df_warn, time_col_warn, SmoothedSpline(); recalibrate=false)

    # Tests for errors
    @test_throws "Unknown finite difference type: unknown" time_to_max_growth(
        od_df, time_col, FiniteDiff(type=:unknown))
end

@testitem "lag time" begin
    println("lag time")
    using DataFrames
    function f(t)
        if t < 5
            return 0
        elseif t < 15
            return 1 / (1 + exp(-2 * (t - 10)))
        else
            return 1
        end
    end
    t = 0:0.5:20
    r = [
        0.5847079560316877, 0.45840079479217205, -1.2615416418439265, -0.19302484376033796,
        -0.4244814803886498, -0.18088313464643485, -0.5045323424725897,
        -0.5141211372683038, 1.1616201463480844, 1.3296851114162132, -0.43120471016998424,
        1.2613828599505037, -0.4646636774845288, -0.908398391727798, 0.9282112244792343,
        0.15692696269233736, -0.0401373009174321, -0.312658487708534, -0.8446115669549681,
        -0.15644528491336934, 0.22969924085412563, -1.7463816740617624,
        -0.9362537306327118, 1.0494677762330453, -2.21499715347752, 1.0574000162409678,
        -0.2865517812478418, 1.5192666194062108, -0.2152836487775379, -0.621802452401734,
        -1.3307105978023612, 0.29757022692826623, 1.2294126967973198, -0.7646230207734392,
        -0.11071786613263836, -0.022308315590345632, -2.023482208299797,
        -1.433631515044935, -0.1421872400744148, -1.4318637059194546, -0.4371826293473729]
    od = f.(t) + 0.01 * r
    od_df = DataFrame(A=od)
    using Dates
    time_col = DataFrame(Time=t * 60000)

    @test 5 < lag_time(od_df, time_col, MovingWindow(window_size=5))[1, "A"] < 8
    @test 5 <
        lag_time(od_df, time_col, MovingWindow(window_size=5, method=:Endpoints))[
            1, "A"] < 8
    @test 5 <
        lag_time(od_df, time_col, MovingWindow(window_size=5, method=:LinearOnLog))[
            1, "A"] < 8
    @test 5 < lag_time(od_df, time_col, ExpandingWindow(window_size=5))[1, "A"] < 8
    @test 5 <
        lag_time(od_df, time_col, LinearOnLog(start_time=7, end_time=10))[1, "A"] < 8
    @test 5 < lag_time(od_df, time_col, Endpoints(start_time=7, end_time=10))[1, "A"] <
        8
    @test 5 < lag_time(od_df, time_col, FiniteDiff(); offset=0.01)[1, "A"] < 8
    @test 5 <
        lag_time(od_df, time_col, FiniteDiff(type=:onesided); offset=0.1)[1, "A"] < 8
    @test 5 < lag_time(od_df, time_col, SmoothedSpline())[1, "A"] < 8
    @test 5 < lag_time(od_df, time_col, Logistic())[1, "A"] < 8
    @test 5 < lag_time(od_df, time_col, Gompertz())[1, "A"] < 8
    @test 5 < lag_time(od_df, time_col, ModifiedGompertz())[1, "A"] < 8
    @test 5 < lag_time(od_df, time_col, Richards())[1, "A"] < 8

    # Tests for warnings
    od_df_warn = DataFrame(A=[
        0.05, -0.1, -0.2, -0.4, -0.8, -1.6, -3.2, -6.4, -12.8, -25.6, -51.2])
    time_col_warn = DataFrame(:Time => 0:60000:600000)
    @test_logs (:warn, r"Not enough data points") match_mode=:any lag_time(
        od_df_warn, time_col_warn, FiniteDiff(); recalibrate=false)
    @test_logs (:warn, r"Not enough data points") match_mode=:any lag_time(
        od_df_warn, time_col_warn, LinearOnLog(start_time=1, end_time=1.5); recalibrate=false)
    @test_logs (:warn, r"Not enough data points") match_mode=:any lag_time(
        od_df_warn, time_col_warn, SmoothedSpline(); recalibrate=false)

    # Tests for errors
    @test_throws "Unknown finite difference type: unknown" lag_time(
        od_df, time_col, FiniteDiff(type=:unknown))
end

@testitem "od at max growth" begin
    println("od at max growth")
    using DataFrames
    function f(t)
        if t < 5
            return 0
        elseif t < 15
            return 1 / (1 + exp(-2 * (t - 10)))
        else
            return 1
        end
    end
    t = 0:0.5:20
    r = [
        0.5847079560316877, 0.45840079479217205, -1.2615416418439265, -0.19302484376033796,
        -0.4244814803886498, -0.18088313464643485, -0.5045323424725897,
        -0.5141211372683038, 1.1616201463480844, 1.3296851114162132, -0.43120471016998424,
        1.2613828599505037, -0.4646636774845288, -0.908398391727798, 0.9282112244792343,
        0.15692696269233736, -0.0401373009174321, -0.312658487708534, -0.8446115669549681,
        -0.15644528491336934, 0.22969924085412563, -1.7463816740617624,
        -0.9362537306327118, 1.0494677762330453, -2.21499715347752, 1.0574000162409678,
        -0.2865517812478418, 1.5192666194062108, -0.2152836487775379, -0.621802452401734,
        -1.3307105978023612, 0.29757022692826623, 1.2294126967973198, -0.7646230207734392,
        -0.11071786613263836, -0.022308315590345632, -2.023482208299797,
        -1.433631515044935, -0.1421872400744148, -1.4318637059194546, -0.4371826293473729]
    od = f.(t) + 0.01 * r
    od_df = DataFrame(A=od)
    using Dates
    time_col = DataFrame(Time=t * 60000)

    @test 0 < od_at_max_growth(od_df, time_col, MovingWindow(window_size=5))[1, "A"] <
        f(10)
    @test 0 <
        od_at_max_growth(
            od_df, time_col, MovingWindow(window_size=5, method=:Endpoints))[1, "A"] <
        f(10)
    @test 0 <
        od_at_max_growth(
            od_df, time_col, MovingWindow(window_size=5, method=:LinearOnLog))[
            1, "A"] < f(10)
    @test 0 < od_at_max_growth(od_df, time_col, ExpandingWindow(window_size=5))[1, "A"] <
        f(10)
    @test 0 <
        od_at_max_growth(od_df, time_col, LinearOnLog(start_time=7, end_time=10))[
            1, "A"] < f(10)
    @test 0 <
        od_at_max_growth(od_df, time_col, Endpoints(start_time=7, end_time=10))[
            1, "A"] < f(10)
    @test 0 < od_at_max_growth(od_df, time_col, FiniteDiff(); offset=0.01)[1, "A"] < f(10)
    @test 0 <
        od_at_max_growth(od_df, time_col, FiniteDiff(type=:onesided); offset=0.1)[
            1, "A"] <
        f(10)
    @test 0 < od_at_max_growth(od_df, time_col, SmoothedSpline())[1, "A"] < f(10)
    @test 0 < od_at_max_growth(od_df, time_col, Logistic())[1, "A"] < f(10)
    @test 0 < od_at_max_growth(od_df, time_col, Gompertz())[1, "A"] < f(10)
    @test 0 < od_at_max_growth(od_df, time_col, ModifiedGompertz())[1, "A"] < f(10)
    @test 0 < od_at_max_growth(od_df, time_col, Richards())[1, "A"] < f(10)

    # Tests for warnings
    od_df_warn = DataFrame(A=[
        0.05, -0.1, -0.2, -0.4, -0.8, -1.6, -3.2, -6.4, -12.8, -25.6, -51.2])
    time_col_warn = DataFrame(:Time => 0:60000:600000)
    @test_logs (:warn, r"Not enough data points") match_mode=:any od_at_max_growth(
        od_df_warn, time_col_warn, FiniteDiff(); recalibrate=false)
    @test_logs (:warn, r"Not enough data points") match_mode=:any od_at_max_growth(
        od_df_warn, time_col_warn, LinearOnLog(start_time=1, end_time=1.5); recalibrate=false)
    @test_logs (:warn, r"Not enough data points") match_mode=:any od_at_max_growth(
        od_df_warn, time_col_warn, SmoothedSpline(); recalibrate=false)

    # Tests for errors
    @test_throws "Unknown finite difference type: unknown" od_at_max_growth(
        od_df, time_col, FiniteDiff(type=:unknown))
end

@testitem "max od" begin
    println("max od")
    using DataFrames
    function f(t)
        if t < 5
            return 0
        elseif t < 15
            return 1 / (1 + exp(-2 * (t - 10)))
        else
            return 1
        end
    end
    t = 0:0.5:20
    r = [
        0.5847079560316877, 0.45840079479217205, -1.2615416418439265, -0.19302484376033796,
        -0.4244814803886498, -0.18088313464643485, -0.5045323424725897,
        -0.5141211372683038, 1.1616201463480844, 1.3296851114162132, -0.43120471016998424,
        1.2613828599505037, -0.4646636774845288, -0.908398391727798, 0.9282112244792343,
        0.15692696269233736, -0.0401373009174321, -0.312658487708534, -0.8446115669549681,
        -0.15644528491336934, 0.22969924085412563, -1.7463816740617624,
        -0.9362537306327118, 1.0494677762330453, -2.21499715347752, 1.0574000162409678,
        -0.2865517812478418, 1.5192666194062108, -0.2152836487775379, -0.621802452401734,
        -1.3307105978023612, 0.29757022692826623, 1.2294126967973198, -0.7646230207734392,
        -0.11071786613263836, -0.022308315590345632, -2.023482208299797,
        -1.433631515044935, -0.1421872400744148, -1.4318637059194546, -0.4371826293473729]
    od = f.(t) + 0.01 * r
    od_df = DataFrame(A=od)
    using Dates
    time_col = DataFrame(Time=t * 60000)

    @test 0.95 < max_od(od_df, time_col, MovingWindow(window_size=5))[1, "A"] < 1.05
    @test 0.95 <
        max_od(od_df, time_col, MovingWindow(window_size=5, method=:Endpoints))[
            1, "A"] < 1.05
    @test 0.95 <
        max_od(od_df, time_col, MovingWindow(window_size=5, method=:LinearOnLog))[
            1, "A"] < 1.05
    @test 0.95 < max_od(od_df, time_col, ExpandingWindow(window_size=5))[1, "A"] < 1.05
    @test 0.95 <
        max_od(od_df, time_col, LinearOnLog(start_time=7, end_time=10))[1, "A"] < 1.05
    @test 0.95 < max_od(od_df, time_col, Endpoints(start_time=7, end_time=10))[1, "A"] <
        1.05
    @test 0.95 < max_od(od_df, time_col, FiniteDiff())[1, "A"] < 1.05
    @test 0.95 < max_od(od_df, time_col, FiniteDiff(type=:onesided))[1, "A"] < 1.05
    @test 0.95 < max_od(od_df, time_col, SmoothedSpline(); offset=0.05)[1, "A"] < 1.05
    @test 0.95 < max_od(od_df, time_col, Logistic())[1, "A"] < 1.05
    @test 0.95 < max_od(od_df, time_col, Gompertz())[1, "A"] < 1.05
    @test_skip 0.95 < max_od(od_df, time_col, ModifiedGompertz())[1, "A"] < 1.05
    @test 0.95 < max_od(od_df, time_col, Richards())[1, "A"] < 1.05

    # Tests for warnings
    od_df_warn = DataFrame(A=[
        0.05, -0.1, -0.2, -0.4, -0.8, -1.6, -3.2, -6.4, -12.8, -25.6, -51.2])
    time_col_warn = DataFrame(:Time => 0:60000:600000)
    @test_logs (:warn, r"Not enough data points") match_mode=:any max_od(
        od_df_warn, time_col_warn, FiniteDiff(); recalibrate=false)
    @test_logs (:warn, r"Not enough data points") match_mode=:any max_od(
        od_df_warn, time_col_warn, LinearOnLog(start_time=1, end_time=1.5); recalibrate=false)
    @test_logs (:warn, r"Not enough data points") match_mode=:any max_od(
        od_df_warn, time_col_warn, SmoothedSpline(); recalibrate=false)

    # Tests for errors
    @test_throws "Unknown finite difference type: unknown" max_od(
        od_df, time_col, FiniteDiff(type=:unknown))
end

@testitem "growth curve plots" begin
    println("growth curve plots")
    using DataFrames
    function f(t)
        if t < 5
            return 0
        elseif t < 15
            return 1 / (1 + exp(-2 * (t - 10)))
        else
            return 1
        end
    end
    t = 0:0.5:20
    r = [
        0.5847079560316877, 0.45840079479217205, -1.2615416418439265, -0.19302484376033796,
        -0.4244814803886498, -0.18088313464643485, -0.5045323424725897,
        -0.5141211372683038, 1.1616201463480844, 1.3296851114162132, -0.43120471016998424,
        1.2613828599505037, -0.4646636774845288, -0.908398391727798, 0.9282112244792343,
        0.15692696269233736, -0.0401373009174321, -0.312658487708534, -0.8446115669549681,
        -0.15644528491336934, 0.22969924085412563, -1.7463816740617624,
        -0.9362537306327118, 1.0494677762330453, -2.21499715347752, 1.0574000162409678,
        -0.2865517812478418, 1.5192666194062108, -0.2152836487775379, -0.621802452401734,
        -1.3307105978023612, 0.29757022692826623, 1.2294126967973198, -0.7646230207734392,
        -0.11071786613263836, -0.022308315590345632, -2.023482208299797,
        -1.433631515044935, -0.1421872400744148, -1.4318637059194546, -0.4371826293473729]
    od = f.(t) + 0.01 * r
    od_df = DataFrame(A=od)
    using Dates
    time_col = DataFrame(Time=t * 60000)

    # Add second column of data
    od_df[!, "B"] = od_df[!, "A"] .+ 0.1

    using Logging
    io = IOBuffer()
    logger = SimpleLogger(io)

    # Call growth_rate with all methods and check that plots are produced
    for method in (MovingWindow(window_size=5), ExpandingWindow(), LinearOnLog(start_time=7, end_time=10), Endpoints(start_time=7, end_time=10), FiniteDiff(), SmoothedSpline(), Logistic(), Gompertz(), ModifiedGompertz(), Richards())
        with_logger(logger) do
            growth_rate(od_df, time_col, method; plot_directory=:temp)
        end
        str = String(take!(io))
        str = replace(str, "┌ Info: Saving plots to temporary directory: " => "")
        str = split(str, "\n")[1]
        @test isdir(str)
        if hasproperty(method, :method)
            extra = method.method
        elseif hasproperty(method, :type)
            extra = method.type
        elseif hasproperty(method, :alg)
            extra = method.alg
        elseif hasproperty(method, :name)
            extra = method.name
        else
            extra = ""
        end
        if extra != ""
            @test isfile(joinpath(str, "growth_curve_$(nameof(typeof(method)))_$(extra)_A.png"))
            @test isfile(joinpath(str, "growth_curve_$(nameof(typeof(method)))_$(extra)_B.png"))
        else
            @test isfile(joinpath(str, "growth_curve_$(nameof(typeof(method)))_A.png"))
            @test isfile(joinpath(str, "growth_curve_$(nameof(typeof(method)))_B.png"))
        end
    end

    for func in (time_to_max_growth, lag_time, od_at_max_growth, max_od)
        # Run the function and log the temporary directory
        with_logger(logger) do
            func(od_df, time_col, FiniteDiff(); plot_directory=:temp)
        end
        str = String(take!(io))
        str = replace(str, "┌ Info: Saving plots to temporary directory: " => "")
        str = split(str, "\n")[1]
        @test isfile(joinpath(str, "growth_curve_FiniteDiff_central_A.png"))
        @test isfile(joinpath(str, "growth_curve_FiniteDiff_central_B.png"))
    end

    # Check user-specified directory
    custom_dir = mktempdir()
    growth_rate(od_df, time_col, FiniteDiff(); plot_directory=custom_dir)
    @test isdir(custom_dir)
    @test isfile(joinpath(custom_dir, "growth_curve_FiniteDiff_central_A.png"))
    @test isfile(joinpath(custom_dir, "growth_curve_FiniteDiff_central_B.png"))
end

@testitem "calibrate" begin
    println("calibrate")
    using DataFrames

    data = DataFrame(A=[0.5, 0.65, 0.79, 0.83, 0.95], B=[1.11, 1.05, 1.23, 1.36, 1.44])
    time_col = DataFrame(Time=0:600000:2400000)
    datacopy = deepcopy(data)
    blanks = DataFrame(C=[0.1, 0.15, 0.2, 0.17, 0.08], D=[0.21, 0.26, 0.22, 0.23, 0.2])

    @test calibrate(data, time_col, TimeseriesBlank(blanks=blanks)) ≈
        DataFrame(A=[0.5 - 0.155, 0.65 - 0.205, 0.79 - 0.21, 0.83 - 0.2, 0.95 - 0.14],
        B=[1.11 - 0.155, 1.05 - 0.205, 1.23 - 0.21, 1.36 - 0.2, 1.44 - 0.14])
    @test data == datacopy # Check mutation free
    new_blanks = DataFrame(C=[0.12, 0.14, 0.19], D=[0.22, 0.25, 0.21])
    new_blanks_copy = deepcopy(new_blanks)
    blank_time_col = DataFrame(Time=[
        300000, 1500000, 2100000])
    @test calibrate(data, time_col,
        TimeseriesBlank(blanks=new_blanks, time_col=blank_time_col)) ≈
        DataFrame(
        A=[0.5 - 0.17, 0.65 - (0.75 * 0.17 + 0.25 * 0.195),
            0.79 - (0.25 * 0.17 + 0.75 * 0.195),
            0.83 - (0.5 * 0.195 + 0.5 * 0.20), 0.95 - 0.20],
        B=[1.11 - 0.17, 1.05 - (0.75 * 0.17 + 0.25 * 0.195),
            1.23 - (0.25 * 0.17 + 0.75 * 0.195),
            1.36 - (0.5 * 0.195 + 0.5 * 0.20), 1.44 - 0.20])
    @test data == datacopy
    @test new_blanks == new_blanks_copy

    tmp = calibrate(data, time_col, SmoothedTimeseriesBlank(blanks=blanks))
    @test all(all.(eachcol(tmp .< data)))
    diffs = diff.(eachcol(tmp .- data))
    @test all(all.([d .≈ diffs[1][1] for d in diffs]))
    @test data == datacopy

    tmp = calibrate(data, time_col,
        SmoothedTimeseriesBlank(blanks=new_blanks, time_col=blank_time_col))
    @test all(all.(eachcol(tmp .< data)))
    diffs = diff.(eachcol(tmp .- data))
    @test all(all.([d .≈ diffs[1][1] for d in diffs]))
    @test data == datacopy
    @test new_blanks == new_blanks_copy

    @test calibrate(data, time_col, MeanBlank(blanks=blanks)) ==
        DataFrame(
        A=[0.5 - 0.182, 0.65 - 0.182, 0.79 - 0.182, 0.83 - 0.182, 0.95 - 0.182],
        B=[1.11 - 0.182, 1.05 - 0.182, 1.23 - 0.182, 1.36 - 0.182, 1.44 - 0.182])
    @test data == datacopy
    @test calibrate(data, time_col, MinBlank(blanks=blanks)) ==
        DataFrame(A=[0.5 - 0.08, 0.65 - 0.08, 0.79 - 0.08, 0.83 - 0.08, 0.95 - 0.08],
        B=[1.11 - 0.08, 1.05 - 0.08, 1.23 - 0.08, 1.36 - 0.08, 1.44 - 0.08])
    @test data == datacopy
    @test calibrate(data, time_col, MinData()) ==
        DataFrame(A=[0.5 - 0.5, 0.65 - 0.5, 0.79 - 0.5, 0.83 - 0.5, 0.95 - 0.5],
        B=[1.11 - 1.05, 1.05 - 1.05, 1.23 - 1.05, 1.36 - 1.05, 1.44 - 1.05])
    @test data == datacopy
    @test calibrate(data, time_col, StartData()) ==
        DataFrame(A=[0.5 - 0.5, 0.65 - 0.5, 0.79 - 0.5, 0.83 - 0.5, 0.95 - 0.5],
        B=[1.11 - 1.11, 1.05 - 1.11, 1.23 - 1.11, 1.36 - 1.11, 1.44 - 1.11])
    @test data == datacopy

    # offset
    @test calibrate(data, time_col, StartData(); offset=0.1) ==
        DataFrame(
        A=[0.5 - 0.5 + 0.1, 0.65 - 0.5 + 0.1, 0.79 - 0.5 + 0.1,
            0.83 - 0.5 + 0.1, 0.95 - 0.5 + 0.1],
        B=[1.11 - 1.11 + 0.1, 1.05 - 1.11 + 0.1, 1.23 - 1.11 + 0.1,
            1.36 - 1.11 + 0.1, 1.44 - 1.11 + 0.1])

    # missing data
    data = DataFrame(A=[missing, missing, 0.79, 0.83, missing], B=[missing, missing, 1.23, 1.36, missing])
    time_col = DataFrame(Time=[missing, missing, 1200000, 1800000, missing])
    datacopy = deepcopy(data)
    blanks = DataFrame(C=[missing, missing, 0.2, 0.17, 0.08], D=[missing, missing, 0.22, 0.23, missing])
    tmp = calibrate(data, time_col, SmoothedTimeseriesBlank(blanks=blanks))
    @test collect(skipmissing(tmp[:, :A])) ≈ [0.79 - 0.21, 0.83 - 0.2]
    @test collect(skipmissing(tmp[:, :B])) ≈ [1.23 - 0.21, 1.36 - 0.2]
    tmp = calibrate(data, time_col, TimeseriesBlank(blanks=blanks))
    @test collect(skipmissing(tmp[:, :A])) ≈ [0.79 - 0.21, 0.83 - 0.2]
    @test collect(skipmissing(tmp[:, :B])) ≈ [1.23 - 0.21, 1.36 - 0.2]
end

@testitem "fluorescence per cell" setup=[environment_path] begin
    println("fluorescence per cell")
    using DataFrames

    lw = read_data("inputs/biotek.xlsx")
    filename = joinpath(Base.Filesystem.mktempdir(), "tmp.lw")
    write_longwing(lw, filename)
    lw = read_longwing(filename)
    trans_meta_map = Dict(Symbol(i) => Meta.parse(lw.transformations[i]["equation"])
                          for i in keys(lw.transformations))

    # Single sample with no calibration
    od = eval(Longwing.sexp_to_nested_list(:(plate_01_a2.od1), lw, trans_meta_map))
    fl = eval(Longwing.sexp_to_nested_list(:(plate_01_a2.flu1), lw, trans_meta_map))
    time_od = eval(Longwing.sexp_to_nested_list(:(plate_01_time.od1), lw, trans_meta_map))
    time_fl = eval(Longwing.sexp_to_nested_list(:(plate_01_time.flu1), lw, trans_meta_map))

    # Doesn't include any calibration (od or flu) so numbers are kind of meaningless
    @test floor(fluorescence(fl, time_fl, od, time_od, RatioAtTime(4 * 60))[1, 1]) == 5455
    @test floor(fluorescence(
        fl, time_fl, od, time_od, RatioAtMaxGrowth(method=FiniteDiff(type=:central)))[
        1, 1]) == 4069

    # Plot directory
    rm(joinpath(pwd(), "fluorescence_per_cell_plate_01_a2.png"), force=true)
    @test !isfile(joinpath(pwd(), "fluorescence_per_cell_plate_01_a2.png"))
    @test floor(fluorescence(
        fl, time_fl, od, time_od, RatioAtMaxGrowth(method=FiniteDiff(type=:central)); plot_directory=".")[
        1, 1]) == 4069
    @test isfile(joinpath(pwd(), "fluorescence_per_cell_plate_01_a2.png"))
    rm(joinpath(pwd(), "fluorescence_per_cell_plate_01_a2.png"), force=true)

    # Including calibration and groups
    od = eval(Longwing.sexp_to_nested_list(:(plate1.od1), lw, trans_meta_map))
    fl = eval(Longwing.sexp_to_nested_list(:(plate1.flu1), lw, trans_meta_map))
    time_od = eval(Longwing.sexp_to_nested_list(:(plate_01_time.od1), lw, trans_meta_map))
    time_fl = eval(Longwing.sexp_to_nested_list(:(plate_01_time.flu1), lw, trans_meta_map))
    od = calibrate(od, time_od, StartData())
    fl = calibrate(fl, time_fl, StartData())
    @test floor(fluorescence(fl, time_fl, od, time_od, RatioAtTime(4 * 60))[
        1, "plate_01_b6"]) == 102
    dir = mktempdir()
    @test floor(fluorescence(
        fl, time_fl, od, time_od,
        RatioAtMaxGrowth(method=LinearOnLog(start_time=220, end_time=300), plot_directory=dir))[
        1, "plate_01_a10"]) == 1411
    # Check files exist in plot directory
    @test length(readdir(dir)) > 0

    # Check that missing values doesn't break things
    missing_indexes = [1, 2, 3, 4, 5]
    allowmissing!(od)
    allowmissing!(fl)
    allowmissing!(time_fl)
    allowmissing!(time_od)
    od[missing_indexes, :] .= missing
    fl[missing_indexes, :] .= missing
    time_fl[missing_indexes, :] .= missing
    time_od[missing_indexes, :] .= missing
    tmp = fluorescence(fl, time_fl, od, time_od, RatioAtTime(4 * 60); plot_directory=:temp)
    @test ismissing(fluorescence(fl, time_fl, od, time_od, RatioAtTime(1 * 60); plot_directory=:temp)[1, 1])
end

@testitem "warning for calibrating multiple channels" begin
    lw = read_longwing("inputs/example.lw")
    trans_meta_map = Dict(Symbol(i) => Meta.parse(lw.transformations[i]["equation"])
                          for i in keys(lw.transformations))
    data = eval(Longwing.sexp_to_nested_list(:(plate_01_a1), lw, trans_meta_map))
    time_col = eval(Longwing.sexp_to_nested_list(:(plate_01_time), lw, trans_meta_map))
    blanks = eval(Longwing.sexp_to_nested_list(:(plate_01_a2), lw, trans_meta_map))
    methods = [TimeseriesBlank(blanks=blanks), SmoothedTimeseriesBlank(blanks=blanks),
        MeanBlank(blanks=blanks), MinBlank(blanks=blanks)]
    for method in methods
        @test_throws "ArgumentError: Multiple channels detected in blanks DataFrame. You may have forgotten to qualify the calibration data with a channel name. Detected channels: [\"OD\", \"flo\"]." calibrate(
            data, time_col, method)
    end
end

@testitem "floating point time error" begin
    println("floating point time error")
    # This checks if a floating point time that, after being multipled by 1000, does not fall on an integer, still reads correctly
    data = read("inputs/bmg-time-error.csv", BMG())[1]
    @test 33047800 in data["ABS_700_0_nm"][!, "time"]
end

@testitem "od thresholds - growth rate" begin
    println("od thresholds - growth rate")
    using DataFrames
    od_df = DataFrame(A=[0.05, 0.1, 0.2, 0.4, 0.8, 1.6, 3.2, 6.4, 12.8, 25.6, 51.2])
    od_df = between(od_df; min_value=0.2, max_value=10)
    time_col = DataFrame(Time=0:60000:600000)

    @test growth_rate(od_df, time_col, MovingWindow(window_size=3))[1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, MovingWindow(window_size=3, method=:Endpoints))[
        1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, MovingWindow(window_size=3, method=:LinearOnLog))[
        1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, LinearOnLog(start_time=3, end_time=6))[
        1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, Endpoints(start_time=3, end_time=6))[
        1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, FiniteDiff())[1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, FiniteDiff(type=:onesided))[1, "A"] ≈ log(2)
    @test growth_rate(od_df, time_col, SmoothedSpline())[1, "A"] ≈ log(2)

    # Parametric tests
    using Dates
    time_col = DataFrame(:Time => 0:10000:600000)
    # Requires full curve, not just a bit of exponential growth
    f(t) = exp(0.7 / (1 + exp(-2.0 * (t - 5.0))))
    od_df = f.(time_col ./ 60000)
    rename!(od_df, :Time => :A)

    od_df = between(od_df; min_value=1.0005, max_value=2.013)
    # Check for missing values
    @test any(ismissing, od_df[!, "A"])

    # Check that the actual growth rate is around 0.35
    @test growth_rate(od_df, time_col, FiniteDiff())[1, "A"]≈0.35 atol=1e-2

    # Test the parametric methods
    @test growth_rate(od_df, time_col, Logistic())[1, "A"]≈0.35 atol=1e-2
    @test growth_rate(od_df, time_col, Gompertz())[1, "A"]≈0.35 atol=0.025
    @test growth_rate(od_df, time_col, ModifiedGompertz())[1, "A"]≈0.35 atol=0.025
    @test growth_rate(od_df, time_col, Richards())[1, "A"]≈0.35 atol=1e-2

    # Test lagtime doesn't return missing for any method
    @test !ismissing(lag_time(od_df, time_col, MovingWindow(window_size=3, method=:Endpoints))[1, "A"])
    @test !ismissing(lag_time(od_df, time_col, MovingWindow(window_size=3, method=:LinearOnLog))[1, "A"])
    @test !ismissing(lag_time(od_df, time_col, ExpandingWindow(window_size=3))[1, "A"])
    @test !ismissing(lag_time(od_df, time_col, LinearOnLog(start_time=3, end_time=6))[1, "A"])
    @test !ismissing(lag_time(od_df, time_col, Endpoints(start_time=3, end_time=6))[1, "A"])
    @test !ismissing(lag_time(od_df, time_col, FiniteDiff())[1, "A"])
    @test !ismissing(lag_time(od_df, time_col, FiniteDiff(type=:onesided))[1, "A"])
    @test !ismissing(lag_time(od_df, time_col, SmoothedSpline())[1, "A"])
    @test !ismissing(lag_time(od_df, time_col, Logistic())[1, "A"])
    @test !ismissing(lag_time(od_df, time_col, Gompertz())[1, "A"])
    @test !ismissing(lag_time(od_df, time_col, ModifiedGompertz())[1, "A"])
    @test !ismissing(lag_time(od_df, time_col, Richards())[1, "A"])

    # If no data points are above the threshold, lag time should return NaN
    od_df_low = between(od_df; min_value=100.0, max_value=100.0)
    @test isnan(lag_time(od_df_low, time_col, MovingWindow(window_size=3, method=:Endpoints))[1, "A"])
end

@testitem "od thresholds - calibrate" begin
    println("od thresholds - calibrate")
    using DataFrames

    data = DataFrame(A=[0.5, 0.65, 0.79, 0.83, 0.95], B=[1.11, 1.05, 1.23, 1.36, 1.44])
    time_col = DataFrame(Time=0:600000:2400000)
    blanks = DataFrame(C=[0.1, 0.15, 0.2, 0.17, 0.08], D=[0.21, 0.26, 0.22, 0.23, 0.2])
    data = between_times(data, time_col; mint=15, maxt=35)
    blanks = between_times(blanks, time_col; mint=15, maxt=35)
    datacopy = deepcopy(data)

    @test dropmissing(calibrate(data, time_col, TimeseriesBlank(blanks=blanks))) ≈
        DataFrame(A=[0.79 - 0.21, 0.83 - 0.2],
        B=[1.23 - 0.21, 1.36 - 0.2])
    @test isequal(data, datacopy) # Check mutation free
    new_blanks = DataFrame(C=[0.12, 0.14, 0.19], D=[0.22, 0.25, 0.21])
    new_blanks_copy = deepcopy(new_blanks)
    blank_time_col = DataFrame(Time=[
        300000, 1500000, 2100000])
    @test dropmissing(calibrate(data, time_col,
        TimeseriesBlank(blanks=new_blanks, time_col=blank_time_col))) ≈
        DataFrame(
        A=[0.79 - (0.25 * 0.17 + 0.75 * 0.195),
            0.83 - (0.5 * 0.195 + 0.5 * 0.20)],
        B=[1.23 - (0.25 * 0.17 + 0.75 * 0.195),
            1.36 - (0.5 * 0.195 + 0.5 * 0.20)])
    @test isequal(data, datacopy)
    @test isequal(new_blanks, new_blanks_copy)

    tmp = calibrate(data, time_col, SmoothedTimeseriesBlank(blanks=blanks))
    @test 0 < nrow(dropmissing(tmp)) < nrow(data) == nrow(tmp)

    @test dropmissing(calibrate(data, time_col, MeanBlank(blanks=blanks))) ≈
        DataFrame(
        A=[0.79 - 0.205, 0.83 - 0.205],
        B=[1.23 - 0.205, 1.36 - 0.205])
    @test isequal(data, datacopy)
    @test dropmissing(calibrate(data, time_col, MinBlank(blanks=blanks))) ==
        DataFrame(A=[0.79 - 0.17, 0.83 - 0.17],
        B=[1.23 - 0.17, 1.36 - 0.17])
    @test isequal(data, datacopy)
    @test dropmissing(calibrate(data, time_col, MinData())) ==
        DataFrame(A=[0.79 - 0.79, 0.83 - 0.79],
        B=[1.23 - 1.23, 1.36 - 1.23])
    @test isequal(data, datacopy)
    @test dropmissing(calibrate(data, time_col, StartData())) ==
        DataFrame(A=[0.79 - 0.79, 0.83 - 0.79],
        B=[1.23 - 1.23, 1.36 - 1.23])
    @test isequal(data, datacopy)

    # offset
    @test dropmissing(calibrate(data, time_col, StartData(); offset=0.1)) ==
        DataFrame(
        A=[0.79 - 0.79 + 0.1, 0.83 - 0.79 + 0.1],
        B=[1.23 - 1.23 + 0.1, 1.36 - 1.23 + 0.1])
end

@testitem "smoothing" begin
    println("smoothing")
    using DataFrames
    data = DataFrame(A=[0.5, 0.65, 0.79, 0.83, 0.95], B=[1.11, 1.05, 1.23, 1.36, 1.44])
    time_col = DataFrame(Time=0:600000:2400000)

    # MovingAverage
    @test smooth(data, time_col, MovingAverage(window_size=3)) ≈
        DataFrame(A=[0.575, 0.64666, 0.75666, 0.85666, 0.89], B=[1.08, 1.13, 1.21333, 1.34333, 1.40]) atol = 1e-4

    @test smooth(data, time_col, MovingAverage(window_size=2)) ≈
        DataFrame(A=[0.5, 0.575, 0.72, 0.81, 0.89], B=[1.11, 1.08, 1.14, 1.295, 1.40]) atol = 1e-4

    @test smooth(data, time_col, MovingAverage(window_size=1)) ≈ data

    @test MovingAverage(window_size=1) == MovingAverage(0, 0)
    @test MovingAverage(window_size=2) == MovingAverage(0, 1)
    @test MovingAverage(window_size=3) == MovingAverage(1, 1)
    @test MovingAverage(window_size=4) == MovingAverage(1, 2)
    @test MovingAverage(window_size=5) == MovingAverage(2, 2)
    @test MovingAverage(window_size=5) == MovingAverage(5)

    # MovingTimeAverage
    @test smooth(data, time_col, MovingTimeAverage(window_size=30)) ≈
        DataFrame(A=[0.575, 0.64666, 0.75666, 0.85666, 0.89], B=[1.08, 1.13, 1.21333, 1.34333, 1.40]) atol = 1e-4

    @test smooth(data, time_col, MovingTimeAverage(window_size=20)) ≈
        DataFrame(A=[0.575, 0.64666, 0.75666, 0.85666, 0.89], B=[1.08, 1.13, 1.21333, 1.34333, 1.40]) atol = 1e-4

    @test smooth(data, time_col, MovingTimeAverage(window_size=10)) ≈ data

    @test MovingTimeAverage(window_size=1) == MovingTimeAverage(0.5, 0.5)
    @test MovingTimeAverage(window_size=2) == MovingTimeAverage(1, 1)
    @test MovingTimeAverage(window_size=3) == MovingTimeAverage(1.5, 1.5)
    @test MovingTimeAverage(window_size=4) == MovingTimeAverage(2, 2)
    @test MovingTimeAverage(window_size=5) == MovingTimeAverage(2.5, 2.5)
    @test MovingTimeAverage(window_size=5) == MovingTimeAverage(5)

    time_col = DataFrame(Time=[0, 60000, 60001, 60002, 240000])
    @test smooth(data, time_col, MovingTimeAverage(window_size=2)) ≈
        DataFrame(A=[0.575, 0.6925, 0.75666, 0.75666, 0.95], B=[1.08, 1.1875, 1.21333, 1.21333, 1.44]) atol = 1e-4
end
