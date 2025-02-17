using Rasters, Test, Aqua, SafeTestsets

if VERSION >= v"1.9.0"
    # Aqua.test_ambiguities([Rasters, Base, Core])
    Aqua.test_unbound_args(Rasters)
    Aqua.test_stale_deps(Rasters, ignore=[:Requires])
    Aqua.test_undefined_exports(Rasters)
    Aqua.test_project_extras(Rasters)
    # Aqua.test_deps_compat(Rasters) # This breaks GDAL downstream tests
    # Aqua.test_project_toml_formatting(Rasters) # This seems to change between versions for extensions
    @time @safetestset "extensions" begin include("extensions.jl") end
end

@time @safetestset "methods" begin include("methods.jl") end
@time @safetestset "array" begin include("array.jl") end
@time @safetestset "stack" begin include("stack.jl") end
@time @safetestset "series" begin include("series.jl") end
@time @safetestset "utils" begin include("utils.jl") end
@time @safetestset "set" begin include("set.jl") end
@time @safetestset "aggregate" begin include("aggregate.jl") end
@time @safetestset "rasterize" begin include("rasterize.jl") end
@time @safetestset "adapt" begin include("adapt.jl") end
@time @safetestset "reproject" begin include("reproject.jl") end
@time @safetestset "warp" begin include("warp.jl") end
@time @safetestset "resample" begin include("resample.jl") end
@time @safetestset "cellsize" begin include("cellsize.jl") end

# CommondataModel sources
@time @safetestset "ncdatasets" begin include("sources/ncdatasets.jl") end
if !Sys.iswindows()
    # GRIBDatasets doesn't work on Windows for now
    @time @safetestset "gribdatasets" begin include("sources/gribdatasets.jl") end
end

# Only test SMAP locally for now, also RasterDataSources because CI dowloads keep breaking
if !haskey(ENV, "CI")
    @time @safetestset "rasterdatasources" begin include("sources/rasterdatasources.jl") end
    @time @safetestset "smap" begin include("sources/smap.jl") end
end

if !Sys.iswindows()
    # GDAL Environment vars need to be set manually for windows, so skip for now
    @time @safetestset "gdal" begin include("sources/gdal.jl") end
    @time @safetestset "grd" begin include("sources/grd.jl") end
end
@time @safetestset "plot recipes" begin include("plotrecipes.jl") end
