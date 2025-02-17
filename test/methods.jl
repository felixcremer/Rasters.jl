using Rasters, Test, ArchGDAL, ArchGDAL.GDAL, Dates, Statistics, DataFrames, Extents, Shapefile, GeometryBasics
import GeoInterface
using Rasters.LookupArrays, Rasters.Dimensions 
using Rasters: bounds

include(joinpath(dirname(pathof(Rasters)), "../test/test_utils.jl"))

A = [missing 7.0f0; 2.0f0 missing]
B = [1.0 0.4; 2.0 missing]
ga = Raster(A, (X(1.0:1:2.0), Y(1.0:1:2.0)); missingval=missing) 
st = RasterStack((a=A, b=B), (X, Y); missingval=(a=missing,b=missing))
st2 = RasterStack((a=A[1,:], b=B), (X, Y); missingval=(a=missing,b=missing))
se = RasterSeries([ga, ga], Rasters.Band(1:2))

pointvec = [(-20.0, 30.0),
            (-20.0, 10.0),
            (0.0, 10.0),
            (0.0, 30.0),
            (-20.0, 30.0)]
vals = [1, 2, 3, 4, 5]
polygon = ArchGDAL.createpolygon(pointvec)
multi_polygon = ArchGDAL.createmultipolygon([[pointvec]])
multi_polygon = ArchGDAL.createmultipolygon([[pointvec]])
multi_point = ArchGDAL.createmultipoint(pointvec)
linestring = ArchGDAL.createlinestring(pointvec)
multi_linestring = ArchGDAL.createmultilinestring([pointvec])
linearring = ArchGDAL.createlinearring(pointvec)
pointfc = map(GeoInterface.getpoint(polygon), vals) do geom, v
    (geometry=geom, val1=v, val2=2.0f0v)
end

test_shape_dir = realpath(joinpath(dirname(pathof(Shapefile)), "..", "test", "shapelib_testcases"))
shp_paths = filter(x -> occursin("shp", x), readdir(test_shape_dir; join=true))
shppath = shp_paths[1]
shphandle = Shapefile.Handle(shppath)

ga99 = replace_missing(ga, -9999)
gaNaN = replace_missing(ga, NaN32)
gaMi = replace_missing(ga)

@testset "replace_missing" begin
    @test eltype(ga99) == Float32
    @test eltype(gaNaN) == Float32
    @test eltype(gaMi) == Union{Float32,Missing}
    @test eltype(replace_missing(ga, 0.0)) == Float64
    @test all(isequal.(ga99, [-9999.0f0 7.0f0; 2.0f0 -9999.0f0]))
    @test missingval(ga99) === -9999.0f0
    @test all(isequal.(gaNaN, [NaN32 7.0f0; 2.0f0 NaN32]))
    @test missingval(gaNaN) === NaN32
    @test all(isequal.(gaMi, ga))
    @test missingval(gaMi) === missing
    # The second layer NaN32 will be promoted to NaN to match the array type
    @test missingval(replace_missing(st, NaN32)) === (a=NaN32, b=NaN)
    @test all(map(values(replace_missing(st, NaN32)), (a=[NaN32 7.0f0; 2.0f0 NaN32], b=[1.0 0.4; 2.0 NaN])) do x, y
        all(x .=== y)
    end)
    ga
    dNaN = replace_missing(ga, NaN32; filename="test.tif")
    @test all(isequal.(dNaN, [NaN32 7.0f0; 2.0f0 NaN32]))
    rm("test.tif")
    stNaN = replace_missing(st, NaN32; filename="teststack.tif")
    @test all(map(stNaN[Band(1)], (a=[NaN32 7.0f0; 2.0f0 NaN32], b=[1.0 0.4; 2.0 NaN])) do x, y
        all(x .=== y)
    end)
    rm("teststack_a.tif")
    rm("teststack_b.tif")
end

@testset "boolmask" begin
    @test boolmask(ga) == [false true; true false]
    @test parent(boolmask(ga)) isa BitMatrix
    @test boolmask(ga99) == [false true; true false]
    @test boolmask(gaNaN) == [false true; true false]
    @test all(boolmask(st[(:b, :a)], alllayers = true) .=== [false true; true false])
    @test all(boolmask(st[(:b, :a)], alllayers = false) .=== [true true; true false])    
    @test all(boolmask(st[(:b, :a)], alllayers = false, missingval = 7.0) .=== [true true; true true])    
    @test all(boolmask(st[(:b, :a)], alllayers = true, missingval = 7.0) .=== [true false; true true])    
    @test all(boolmask(st, alllayers = true, missingval = (a = missing, b = 0.4)) .=== [false false; true false])    
    @test_throws ArgumentError boolmask(st, alllayers = true, missingval = (b = missing, a = 0.4))  
    se2 = RasterSeries([st.b, st.a], Rasters.Band(1:2))
    @test all(boolmask(se2, alllayers = true) .=== [false true; true false])
    @test all(boolmask(se2, alllayers = false) .=== [true true; true false])    
    @test dims(boolmask(ga)) === dims(ga)
    x = boolmask(polygon; res=1.0) 
    @test x == trues(X(Projected(-20:1.0:-1.0; crs=nothing)), Y(Projected(10.0:1.0:29.0; crs=nothing)))
    @test parent(x) isa BitMatrix
    # With a :geometry axis
    x = boolmask([polygon, polygon]; collapse=false, res=1.0)
    @test eltype(x) == Bool
    @test size(x) == (20, 20, 2)
    @test sum(x) == 800
    @test parent(x) isa BitArray{3}
    x = boolmask([polygon, polygon]; collapse=true, res=1.0)
    @test size(x) == (20, 20)
    @test sum(x) == 400
    @test parent(x) isa BitMatrix
end

@testset "missingmask" begin
    @test all(missingmask(ga) .=== [missing true; true missing])
    @test all(missingmask(ga99) .=== [missing true; true missing])
    @test all(missingmask(gaNaN) .=== [missing true; true missing])
    @test all(missingmask(st[(:b, :a)], alllayers = true) .=== [missing true; true missing])
    @test all(missingmask(st[(:b, :a)], alllayers = false) .=== [true true; true missing])  
    @test all(missingmask(st[(:b, :a)], alllayers = false, missingval = 7.0) .=== [true true; true true])    
    @test all(missingmask(st[(:b, :a)], alllayers = true, missingval = 7.0) .=== [true missing; true true])      
    @test dims(missingmask(ga)) == dims(ga)
    @test all(missingmask(st[(:b, :a)], alllayers = true) .=== [missing true; true missing])
    @test all(missingmask(st[(:b, :a)], alllayers = false) .=== [true true; true missing])    
    mm_st2 = missingmask(st2)
    @test dims(mm_st2) == dims(st2)
    @test all(mm_st2 .=== [missing missing; true missing])    
    @test all(missingmask(st2, alllayers = false) .=== [missing; true])    
    @test all(missingmask(se) .=== missingmask(ga))
    @test missingmask(polygon; res=1.0) == fill!(Raster{Union{Missing,Bool}}(undef, X(Projected(-20:1.0:-1.0; crs=nothing)), Y(Projected(10.0:1.0:29.0; crs=nothing))), true)
    x = missingmask([polygon, polygon]; collapse=false, res=1.0)
    @test eltype(x) == Union{Bool,Missing}
    @test size(x) == (20, 20, 2)
    @test sum(x) == 800
    @test parent(x) isa Array{Union{Missing,Bool},3}
    x = missingmask([polygon, polygon]; collapse=true, res=1.0)
    @test size(x) == (20, 20)
    @test sum(x) == 400
end

@testset "mask" begin
    A1 = [missing 1; 2 3]
    A2 = view([0 missing 1; 0 2 3], :, 2:3)
    ga1 = Raster(A1, (X, Y); missingval=missing)
    ga2 = Raster(A2, (X, Y); missingval=missing)
    @test all(mask(ga1; with=ga) .=== mask(ga2; with=ga) .=== [missing 1; 2 missing])
    ga2 = replace_missing(ga1 .* 1.0; missingval=NaN)
    @test all(mask(ga2; with=ga) .=== [NaN 1.0; 2.0 NaN])
    ga3 = replace_missing(ga1; missingval=-9999)
    mask!(ga3; with=ga)
    @test all(ga3 .=== [-9999 1; 2 -9999])
    dmask = mask(ga3; with=ga, filename="mask.tif")
    @test Rasters.isdisk(dmask)
    rm("mask.tif")
    stmask = mask(replace_missing(st, NaN); with=ga, filename="mask.tif")
    @test Rasters.isdisk(stmask)
    rm("mask_a.tif")
    rm("mask_b.tif")
    poly = polygon
    @testset "to polygon" begin
        for poly in (polygon, multi_polygon) 
            a1 = Raster(ones(X(-20:5; sampling=Intervals(Center())), Y(0:30; sampling=Intervals(Center()))))
            st1 = RasterStack(a1, a1)
            ser1 = RasterSeries([a1, a1], Ti(1:2))
            @test all(
                mask(a1; with=polygon) .===
                mask(st1; with=polygon)[:layer1] .===
                mask(ser1; with=polygon)[1]
            )
            # TODO: investigate this more for Points/Intervals
            # Exactly how do we define when boundary values are inside/outside a polygon
            @test sum(skipmissing(mask(a1; with=polygon, boundary=:inside))) == 19 * 19
            @test sum(skipmissing(mask(a1; with=polygon, boundary=:center))) == 20 * 20
            @test sum(skipmissing(mask(a1; with=polygon, boundary=:touches))) == 21 * 21
            mask(a1; with=polygon, boundary=:touches)
            mask(a1; with=polygon, boundary=:touches, shape=:line)
            mask(a1; with=polygon, boundary=:inside)
            mask(a1; with=polygon)
        end
    end
end

@testset "mask_replace_missing" begin
    # Floating point rasters
    a = Raster([1.0 0.0; 1.0 1.0], dims=(X, Y), missingval=0)
    b = Raster([1.0 1.0; 1.0 0.0], dims=(X, Y), missingval=0)

    # Integer rasters
    c = Raster([1 0; 1 1], dims=(X, Y), missingval=0)
    d = Raster([1 1; 1 0], dims=(X, Y), missingval=0)

    # Test that missingval is replaced in source mask (Floats)
    @test isequal(mask(a, with=b, missingval=3.14), [1.0 3.14; 1.0 3.14]) # Test missingval = 3.14
    @test isequal(mask(a, with=b, missingval=missing), [1.0 missing; 1.0 missing]) # Test missingval = missing
    @test isequal(mask(a, with=b, missingval=NaN), [1.0 NaN; 1.0 NaN]) # Test missingval = NaN
    @test isequal(mask(a, with=b, missingval=NaN32), [1.0 NaN; 1.0 NaN]) # Test convert NaN32 to NaN
    @test isequal(mask(a, with=b, missingval=Inf), [1.0 Inf; 1.0 Inf]) # Test missingval = Inf
    @test_throws MethodError mask(a, with=b, missingval=nothing)

    # Test that missingval is replaced in source mask (Ints)
    @test isequal(mask(c, with=d, missingval=missing), [1 missing; 1 missing]) # Test missingval = missing
    @test isequal(mask(c, with=d, missingval=-1.0), [1 -1; 1 -1])
    @test_throws MethodError mask(c, with=d, missingval=nothing)
    @test_throws InexactError mask(c, with=d, missingval=NaN)
    @test_throws InexactError mask(c, with=d, missingval=3.14)
    @test_throws InexactError mask(c, with=d, missingval=Inf)

    # Test Type Stability
    @test eltype(mask(a, with=b, missingval=0)) == Float64
    @test eltype(mask(a, with=b, missingval=-1)) == Float64
    @test eltype(mask(a, with=b, missingval=Inf32)) == Float64
    @test eltype(mask(Float32.(a), with=b, missingval=Inf)) == Float32
    @test eltype(mask(Float32.(a), with=b, missingval=NaN)) == Float32
    @test eltype(mask(Float32.(a), with=b, missingval=0.0)) == Float32
    @test eltype(mask(Float32.(a), with=b, missingval=0)) == Float32
    @test eltype(mask(Float32.(a), with=b, missingval=-1)) == Float32
    @test eltype(mask(c, with=d, missingval=-1.0)) == Int64
    @test eltype(mask(c, with=d, missingval=0.0f0)) == Int64
    @test eltype(mask(c, with=Float64.(d), missingval=-1.0)) == Int64
    @test eltype(mask(c, with=Float64.(d), missingval=0.0f0)) == Int64

    # Test mask!
    @test_throws MethodError mask!(a, with=b, missingval=missing)
    @test isequal(mask!(deepcopy(a), with=b, missingval=3.14), [1.0 3.14; 1.0 3.14]) # Test missingval = 3.14
    @test isequal(mask!(deepcopy(a), with=b, missingval=NaN), [1.0 NaN; 1.0 NaN]) # Test missingval = NaN
    @test isequal(mask!(deepcopy(a), with=b, missingval=NaN32), [1.0 NaN; 1.0 NaN]) # Test convert NaN32 to NaN
    @test isequal(mask!(deepcopy(a), with=b, missingval=Inf), [1.0 Inf; 1.0 Inf]) # Test missingval = Inf
    @test isequal(mask(deepcopy(c), with=d, missingval=-1.0), [1 -1; 1 -1])
    @test_throws MethodError mask!(deepcopy(a), with=b, missingval=missing)
    @test_throws ArgumentError mask!(deepcopy(c), with=d, missingval=nothing)
    @test_throws InexactError mask!(deepcopy(c), with=d, missingval=NaN)
    @test_throws InexactError mask!(deepcopy(c), with=d, missingval=3.14)
    @test_throws InexactError mask!(deepcopy(c), with=d, missingval=Inf)
end

@testset "zonal" begin
    a = Raster((1:26) * (1:31)', (X(-20:5), Y(0:30)))
    pointvec_empty = [(-100.0, 0.0), (-100.0, 0.0), (-100.0, 0.0), (-100.0, 0.0), (-100.0, 0.0)]
    polygon_empty = ArchGDAL.createpolygon(pointvec_empty)
    zonal(sum, a; of=polygon) ==
        zonal(sum, a; of=[polygon, polygon])[1] ==
        zonal(sum, a; of=[polygon, polygon_empty])[1] ==
        zonal(sum, a; of=(geometry=polygon, x=:a, y=:b)) ==
        zonal(sum, a; of=[(geometry=polygon, x=:a, y=:b)])[1] ==
        zonal(sum, a; of=[(geometry=polygon, x=:a, y=:b)])[1] ==
        sum(skipmissing(mask(a; with=polygon)))
    @test zonal(sum, a; of=a) == 
        zonal(sum, a; of=dims(a)) ==
        zonal(sum, a; of=Extents.extent(a)) == 
        sum(a)

    b = a .* 2
    c = cat(a .* 3, a .* 3; dims=:newdim)
    st = RasterStack((; a, b, c))
    @test zonal(sum, st; of=polygon) == zonal(sum, st; of=[polygon])[1] ==
        zonal(sum, st; of=(geometry=polygon, x=:a, y=:b)) ==
        zonal(sum, st; of=[(geometry=polygon, x=:a, y=:b)])[1] ==
        zonal(sum, st; of=[(geometry=polygon, x=:a, y=:b)])[1] ==
        map(sum ∘ skipmissing, mask(st; with=polygon))  
    @test zonal(sum, st; of=st) == 
        zonal(sum, st; of=dims(st)) == 
        zonal(sum, st; of=Extents.extent(st)) == 
        sum(st)
end

@testset "classify" begin
    A1 = [missing 1; 2 3]
    ga1 = Raster(A1, (X, Y); missingval=missing)
    @test all(classify(ga1, 1=>99, 2=>88, 3=>77) .=== [missing 99; 88 77])
    @test all(classify(ga1, 1=>99, 2=>88, 3=>77; others=0) .=== [missing 99; 88 77])
    @test all(classify(ga1, 1=>99, 2=>88; others=0) .=== [missing 99; 88 0])
    A2 = [1.0 2.5; 3.0 4.0]
    ga2 = Raster(A2, (X, Y); missingval=missing)
    @test classify(ga2, (2, 3)=>:x, >(3)=>:y) == [1.0 :x; 3.0 :y]
    @test classify(ga2, (>=(1), <(2))=>:x, >=(3)=>:y) == [:x 2.5; :y :y]
    classify!(ga2, (1, 2.5)=>0.0, >=(3)=>-1.0; lower=(>), upper=(<=))
    @test ga2 == [1.0 0.0; -1.0 -1.0]
    classify!(ga2, [1 2.5 0.0; 2.5 4.0 -1.0]; lower=(>), upper=(<=))
    @test ga2 == [1.0 0.0; -1.0 -1.0]
    @test all(classify(ga1, [1 99; 2 88; 3 77]) .=== [missing 99; 88 77])
    @test_throws ArgumentError classify(ga1, [1, 2, 3])
end

@testset "points" begin
    ga = Raster(A, (X(9.0:1.0:10.0), Y(0.1:0.1:0.2)); missingval=missing)
    @test all(collect(points(ga; order=(Y, X))) .=== [missing (0.2, 9.0); (0.1, 10.0) missing])
    @test all(collect(points(ga; order=(X, Y))) .=== [missing (9.0, 0.2); (10.0, 0.1) missing])
    @test all(points(ga; order=(X, Y), ignore_missing=true) .===
              [(9.0, 0.1) (9.0, 0.2); (10.0, 0.1) (10.0, 0.2)])
end

# Idea for generic constructors
# Polygon(mod, values) = Polygon(Val{Symbol(mod)}(), values)
# Polygon(::Val{:ArchGDAL}, values) = ArchGDAL.createpolygon(values)

createpoint(args...) = ArchGDAL.createpoint(args...)

@testset "extract" begin
    dimz = (X(9.0:1.0:10.0), Y(0.1:0.1:0.2))
    rast = Raster([1 2; 3 4], dimz; name=:test, missingval=missing)
    rast2 = Raster([5 6; 7 8], dimz; name=:test2, missingval=missing)
    rast_m = Raster([1 2; 3 missing], dimz; name=:test, missingval=missing)
    table = (geometry=[missing, (9.0, 0.1), (9.0, 0.2), (10.0, 0.3)], foo=zeros(4))
    st = RasterStack(rast, rast2)
    @testset "from Raster" begin
        # Tuple points
        ex = extract(rast, [missing, (9.0, 0.1), (9.0, 0.2), (10.0, 0.3)])
        @test eltype(ex) == NamedTuple{(:geometry,:test)}
        @test all(ex .=== [
            (geometry = missing, test = missing)
            (geometry = (9.0, 0.1), test = 1)
            (geometry = (9.0, 0.2), test = 2)
            (geometry = (10.0, 0.3), test = missing)
        ])
        ex = extract(rast_m, [missing, (9.0, 0.1), (9.0, 0.2), (10.0, 0.3)]; skipmissing=true)
        @test eltype(ex) == NamedTuple{(:geometry,:test),Tuple{Tuple{Float64,Float64},Int}}
        @test all(ex .=== [(geometry = (9.0, 0.1), test = 1), (geometry = (9.0, 0.2), test = 2)])
        ex = extract(rast_m, [missing, (9.0, 0.1), (9.0, 0.2), (10.0, 0.3)]; skipmissing=true, geometry=false)
        @test eltype(ex) == NamedTuple{(:test,),Tuple{Int}}
        @test all(ex .=== [(test = 1,), (test = 2,)])
        @test all(extract(rast_m, [missing, (9.0, 0.1), (9.0, 0.2), (10.0, 0.3)]; skipmissing=true, geometry=false, index=true) .=== [
            (index = (1, 1), test = 1,)
            (index = (1, 2), test = 2,)
        ])
        # NamedTuple (reversed) points
        @test all(extract(rast, [missing, (Y=0.1, X=9.0), (Y=0.2, X=10.0), (Y=0.3, X=10.0)]) .=== [
            (geometry = missing, test = missing)
            (geometry = (Y = 0.1, X = 9.0), test = 1)
            (geometry = (Y = 0.2, X = 10.0), test = 4)
            (geometry = (Y = 0.3, X = 10.0), test = missing)
        ])
        # Vector points
        @test all(extract(rast, [[9.0, 0.1], [10.0, 0.2]]) .== [
            (geometry = [9.0, 0.1], test = 1)
            (geometry = [10.0, 0.2], test = 4)
        ])
        # Extract a polygon
        p = ArchGDAL.createpolygon([[[8.0, 0.0], [11.0, 0.0], [11.0, 0.4], [8.0, 0.0]]])
        @test all(extract(rast_m, p) .=== [
            (geometry = (9.0, 0.1), test = 1)
            (geometry = (10.0, 0.1), test = 3)
            (geometry = (10.0, 0.2), test = missing)
        ])
        # Extract a vector of polygons
        ex = extract(rast_m, [p, p])
        @test eltype(ex) == NamedTuple{(:geometry,:test)}
        @test all(ex .=== [
            (geometry = (9.0, 0.1), test = 1)
            (geometry = (10.0, 0.1), test = 3)
            (geometry = (10.0, 0.2), test = missing)
            (geometry = (9.0, 0.1), test = 1)
            (geometry = (10.0, 0.1), test = 3)
            (geometry = (10.0, 0.2), test = missing)
        ])
        # Test all the keyword combinations
        @test all(extract(rast_m, p) .=== [
            (geometry = (9.0, 0.1), test = 1)
            (geometry = (10.0, 0.1), test = 3)
            (geometry = (10.0, 0.2), test = missing)
        ])
        @test all(extract(rast_m, p; geometry=false) .=== [
            (test = 1,)
            (test = 3,)
            (test = missing,)
        ])
        @test all(extract(rast_m, p; geometry=false, index=true) .=== [
            (index = CartesianIndex(1, 1), test = 1)
            (index = CartesianIndex(2, 1), test = 3)
            (index = CartesianIndex(2, 2), test = missing)
        ])
        @test all(extract(rast_m, p; index=true) .=== [
             (geometry = (9.0, 0.1), index = CartesianIndex(1, 1), test = 1)
             (geometry = (10.0, 0.1), index = CartesianIndex(2, 1), test = 3)
             (geometry = (10.0, 0.2), index = CartesianIndex(2, 2), test = missing)
        ])
        @test extract(rast_m, p; skipmissing=true) == [
            (geometry = (9.0, 0.1), test = 1)
            (geometry = (10.0, 0.1), test = 3)
        ]                                                         
        @test extract(rast_m, p; skipmissing=true, geometry=false) == [
            (test = 1,)
            (test = 3,)
        ]                                                         
        @test extract(rast_m, p; skipmissing=true, geometry=false, index=true) == [
            (index = CartesianIndex(1, 1), test = 1)
            (index = CartesianIndex(2, 1), test = 3)
        ]                                                         
        @test extract(rast_m, p; skipmissing=true, index=true) == [
            (geometry = (9.0, 0.1), index = CartesianIndex(1, 1), test = 1)
            (geometry = (10.0, 0.1), index = CartesianIndex(2, 1), test = 3)
        ]                                                         
        # Empty geoms
        @test extract(rast, []) == NamedTuple{(:geometry, :test),Tuple{Missing,Missing}}[]
        @test extract(rast, []; geometry=false) == NamedTuple{(:test,),Tuple{Missing}}[]
        # Missing coord errors
        @test_throws ArgumentError extract(rast, [(0.0, missing), (9.0, 0.1), (9.0, 0.2), (10.0, 0.3)])
        @test_throws ArgumentError extract(rast, [(9.0, 0.1), (0.0, missing), (9.0, 0.2), (10.0, 0.3)])
        @test_throws ArgumentError extract(rast, [(X=0.0, Y=missing), (9.0, 0.1), (9.0, 0.2), (10.0, 0.3)])
    end

    @testset "with table" begin
        @test all(extract(rast, table) .=== [
            (geometry = missing, test = missing)
            (geometry = (9.0, 0.1), test = 1)
            (geometry = (9.0, 0.2), test = 2)
            (geometry = (10.0, 0.3), test = missing)
        ])
        @test extract(rast, table; skipmissing=true) == [
            (geometry = (9.0, 0.1), test = 1)
            (geometry = (9.0, 0.2), test = 2)
        ]
        @test extract(rast, table; skipmissing=true, geometry=false) == [
            (test = 1,)
            (test = 2,)
        ]
        @test extract(rast, table; skipmissing=true, geometry=false, index=true) == [
            (index = (1, 1), test = 1,)
            (index = (1, 2), test = 2,)
        ]
    end

    @testset "from stack" begin
        @test all(extract(st, [missing, (9.0, 0.1), (10.0, 0.2), (10.0, 0.3)]) .=== [
            (geometry = missing, test = missing, test2 = missing)
            (geometry = (9.0, 0.1), test = 1, test2 = 5)
            (geometry = (10.0, 0.2), test = 4, test2 = 8)
            (geometry = (10.0, 0.3), test = missing, test2 = missing)
        ])
        @test extract(st, [missing, (9.0, 0.1), (10.0, 0.2), (10.0, 0.3)]; skipmissing=true) == [
            (geometry = (9.0, 0.1), test = 1, test2 = 5)
            (geometry = (10.0, 0.2), test = 4, test2 = 8)
        ]
        @test extract(st, [missing, (9.0, 0.1), (10.0, 0.2), (10.0, 0.3)]; skipmissing=true, geometry=false) == [
            (test = 1, test2 = 5)
            (test = 4, test2 = 8)
        ]
        @test extract(st, [missing, (9.0, 0.1), (10.0, 0.2), (10.0, 0.3)]; skipmissing=true, geometry=false, index=true) == [
            (index = (1, 1), test = 1, test2 = 5)
            (index = (2, 2), test = 4, test2 = 8)
        ]
        # Subset with `names`
        @test all(extract(st, [missing, (9.0, 0.1), (10.0, 0.2), (10.0, 0.3)]; names=(:test2,)) .=== [
            (geometry = missing, test2 = missing)
            (geometry = (9.0, 0.1), test2 = 5)
            (geometry = (10.0, 0.2), test2 = 8)
            (geometry = (10.0, 0.3), test2 = missing)
        ])
    end
end

@testset "trim, crop, extend" begin
    A = [missing missing missing
         missing 2.0     0.5
         missing 1.0     missing]

    r_fwd = Raster(A, (X(1.0:1.0:3.0), Y(1.0:1.0:3.0)); missingval=missing)
    r_revX = reverse(r_fwd; dims=X)
    r_revY = reverse(r_fwd; dims=Y)

    ga = r_revY
    for ga in (r_fwd, r_revX, r_revY)
        # Test with missing on all sides
        ga_r = rot180(ga)
        trimmed = trim(ga)
        trimmed_r = trim(ga_r)
        trimmed_d = trim(ga_r)
        if ga === r_fwd
            @test all(trimmed .=== [2.0 0.5; 1.0 missing])
            @test all(trimmed_r .=== [missing 1.0; 0.5 2.0])
        end
        cropped = crop(ga; to=trimmed)
        cropped1 = crop(crop(ga; to=dims(trimmed, X)); to=dims(trimmed, Y))
        _, cropped2 = crop(trimmed, ga)
        cropped_r = crop(ga_r; to=trimmed_r)
        @test all(cropped .=== cropped1 .=== trimmed)
        @test all(cropped_r .=== trimmed_r)
        extended = extend(cropped, ga)[1]
        extended_r = extend(cropped_r; to=ga_r)
        extended1 = extend(extend(cropped; to=dims(ga, X)); to=dims(ga, Y))
        extended_d = extend(cropped; to=ga, filename="extended.tif")
        @test all(extended .=== extended1 .=== replace_missing(extended_d) .=== ga) 
        @test all(extended_r .=== ga_r)
        @test all(map(==, lookup(extended_d), lookup(extended)))

        @testset "to polygons" begin
            A1 = Raster(zeros(X(-20:-5; sampling=Points()), Y(0:30; sampling=Points())))
            A2 = Raster(ones(X(-20:-5; sampling=Points()), Y(0:30; sampling=Points())))
            A1crop1 = crop(A1; to=polygon)
            A1crop2, A2crop = crop(A1, A2; to=polygon)
            size(A1crop1)
            @test size(A1crop1) == size(A1crop2) == size(A2crop) == (16, 21)
            @test bounds(A1crop1) == bounds(A1crop2) == bounds(A2crop) == ((-20, -5), (10, 30))
            A1extend1 = extend(A1; to=polygon)
            A1extend2, A2extend = extend(A1, A2; to=polygon)
            @test all(A1extend1 .=== A1extend2)
            @test size(A1extend1) == size(A1extend2) == size(A2extend) == (21, 31)
            @test bounds(A1extend1) == bounds(A1extend2) == bounds(A2extend) == ((-20.0, 0.0), (0, 30))
        end
        @testset "to featurecollection and table" begin
            A1 = Raster(zeros(X(-20:-5; sampling=Points()), Y(0:30; sampling=Points())))
            featurecollection = map(GeoInterface.getpoint(polygon), vals) do geometry, v
                (; geometry, val1=v, val2=2.0f0v)
            end
            fccrop = crop(A1; to=featurecollection)
            table = DataFrame(featurecollection)
            tablecrop = crop(A1; to=table)
            @test size(fccrop) == size(tablecrop) == (16, 21)
            @test bounds(fccrop) == bounds(tablecrop) == ((-20, -5), (10, 30))
        end
    end

end

@testset "mosaic" begin
    reg1 = Raster([0.1 0.2; 0.3 0.4], (X(2.0:1.0:3.0), Y(5.0:1.0:6.0)))
    reg2 = Raster([1.1 1.2; 1.3 1.4], (X(3.0:1.0:4.0), Y(6.0:1.0:7.0)))
    irreg1 = Raster([0.1 0.2; 0.3 0.4], (X([2.0, 3.0]), Y([5.0, 6.0])))
    irreg2 = Raster([1.1 1.2; 1.3 1.4], (X([3.0, 4.0]), Y([6.0, 7.0])))

    span_x1 = Explicit(vcat((1.5:1.0:2.5)', (2.5:1.0:3.5)'))
    span_x2 = Explicit(vcat((2.5:1.0:3.5)', (3.5:1.0:4.5)'))
    exp1 = Raster([0.1 0.2; 0.3 0.4], (X(Sampled([2.0, 3.0]; span=span_x1)), Y([5.0, 6.0])))
    exp2 = Raster([1.1 1.2; 1.3 1.4], (X(Sampled([3.0, 4.0]; span=span_x2)), Y([6.0, 7.0])))
    @test val(span(mosaic(first, exp1, exp2), X)) == [1.5 2.5 3.5; 2.5 3.5 4.5]
    @test all(mosaic(first, [reg1, reg2]) .=== 
              mosaic(first, irreg1, irreg2) .===
              mosaic(first, (irreg1, irreg2)) .=== 
              [0.1 0.2 missing; 
               0.3 0.4 1.2; 
               missing 1.3 1.4])
    @test all(mosaic(last, reg1, reg2) .===
              mosaic(last, irreg1, irreg2) .===
              mosaic(last, exp1, exp2) .=== [0.1 0.2 missing; 
                                             0.3 1.1 1.2; 
                                             missing 1.3 1.4])

    @test all(mosaic(first, [reverse(reg2; dims=Y), reverse(reg1; dims=Y)]) .=== 
              [missing 0.2 0.1; 
               1.2 1.1 0.3; 
               1.4 1.3 missing]
             )

    # 3 dimensions
    A1 = Raster(ones(2, 2, 2), (X(2.0:-1.0:1.0), Y(5.0:1.0:6.0), Ti(DateTime(2001):Year(1):DateTime(2002))))
    A2 = Raster(zeros(2, 2, 2), (X(3.0:-1.0:2.0), Y(4.0:1.0:5.0), Ti(DateTime(2002):Year(1):DateTime(2003))))
    @test all(mosaic(mean, A1, A2) |> parent .=== 
              first(mosaic(mean, RasterStack(A1), RasterStack(A2))) .===
              cat([missing missing missing
                   missing 1.0     1.0
                   missing 1.0     1.0    ],
                   [0.0     0.0 missing
                   0.0     0.5     1.0   
                   missing 1.0     1.0    ],
                   [0.0     0.0     missing
                   0.0     0.0     missing    
                   missing missing missing], dims=3))
end
