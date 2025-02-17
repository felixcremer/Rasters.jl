using Rasters, Test, Dates, Plots, ColorTypes

ga2 = Raster(ones(91) * (-25:15)', (X(0.0:4.0:360.0), Y(-25.0:1.0:15.0), ); name=:Test)
ga3 = Raster(rand(10, 41, 91), (Z(100:100:1000), Y(-20.0:1.0:20.0), X(0.0:4.0:360.0)))
ga4ti = Raster(
    rand(10, 41, 91, 4), 
    (Z(100:100:1000), Y(-20.0:1.0:20.0), X(0.0:4.0:360.0), Ti(Date(2001):Year(1):Date(2004)))
)
ga4x = Raster(
    rand(10, 41, 91, 4), 
    (Z(100:100:1000), Y(-20.0:1.0:20.0), X(0.0:4.0:360.0), X())
);

plot(ga2)
plot(ga3[Y(At(0.0))])
plot(ga3[X(At(180.0))])
plot(ga3)
# Line plot with Z on the vertical axis
plot(ga3[X(At(0.0)), Y(At(0.0))])
# DD fallback line plot with Z as key (not great really)
plot(ga4x[X(At(0.0)), Y(At(0.0))])
plot(ga4x[X(At(0.0))])
# DD fallback heatmap with Z on Y axis
heatmap(ga4x[X(At(0.0)), Y(At(0.0))])
# Cant plot 4d
@test_throws ErrorException plot(ga4x)
# 3d plot by NoLookupArray X dim

@test_broken plot(ga4x[Y(1)])
# 3d plot by Ti dim
plot(ga4ti[Z(1)])
# Rasters handles filled contours
contourf(ga2)
# RasterStack plot
st = RasterStack(ga2, ga3)
plot(st)
plot(st; layout=(2, 1))

# DD fallback
contour(ga2)

# Colors
c = Raster(rand(RGB, Y(-20.0:1.0:20.0), X(0.0:4.0:360.0)))
plot(c)

# Series
plot(RasterSeries([ga2, ga2, ga2], Z))
plot(RasterSeries([ga2 for _ in 1:100], Ti([DateTime(i) for i in 2001:2100])))

#########################
# Makie
# Loading Makie in tests is a huge overhead

if !haskey(ENV, "CI")
    xs = 0.0:4.0:360.0
    ys = -20.0:1.0:20.0
    rast = Raster(rand(X(xs), Y(ys)))

    using GLMakie
    # Some small diversions from the DimensionalData.jl recipes
    @test Makie.convert_arguments(Makie.DiscreteSurface(), rast) == 
        (lookup(rast, X), lookup(rast, Y), Float32.(rast.data))
    # test true 3d rasters just show the first slice
    true_3d_raster = Raster(rand(X(0.0:4.0:360.0), Y(-20.0:1.0:20.0), Ti(1:10)))
    @test Makie.convert_arguments(Makie.DiscreteSurface(), true_3d_raster) ==
        (lookup(true_3d_raster, X), lookup(true_3d_raster, Y), Float32.(true_3d_raster[:, :, 1]))
    # test that singleton 3d dimensions work
    singleton_3d_raster = Raster(rand(X(0.0:4.0:360.0), Y(-20.0:1.0:20.0), Ti(1)))
    converted = Makie.convert_arguments(Makie.DiscreteSurface(), singleton_3d_raster) 
    @test length(converted) == 3
    @test all(collect(converted[end] .== Float32.(singleton_3d_raster.data[:, :, 1]))) # remove if we want to handle 3d rasters with a singleton dimension

    Makie.image(ga2)
    Makie.heatmap(ga3)
    Rasters.rplot(ga2)
    Rasters.rplot(ga3)

    using Colors
    c = Raster(rand(RGB, X(10), Y(10)))
    Makie.image(c)
    # Makie.heatmap(c) # Doesn't work because of the auto Colorbar
end
