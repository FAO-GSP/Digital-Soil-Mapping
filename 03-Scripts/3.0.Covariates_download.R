#######################################################
#
#  Process and download covariates
#  from GEE and Zenodo to R 
#
#  Export both raw covariates and PCAs
#
# GSP-Secretariat
# Contact: Isabel.Luotto@fao.org
#
#######################################################

#Empty environment and cache ----
rm(list = ls());
gc()

#######################################################
#
#  User defined variables:

# Working directory
#wd <- 'C:/Users/luottoi/Documents/GitHub/Digital-Soil-Mapping'
wd <- 'C:/Users/hp/Documents/GitHub/Digital-Soil-Mapping'

# Folder to store global layers from Zenodo
#output_dir <-'C:/Users/hp/Documents/FAO/data/OpenLandMap/'
output_dir <-'C:/Users/luottoi/Documents/data/OpenLandMap/'

# Area of interest: either own shapefile or 3-digit ISO code to extract from UN 2020 boundaries
#AOI <- '01-Data/MKD.shp'
AOI <- 'MKD'
#Start and End time 
start_T <- "2017-01-01"
end_T <- "2017-12-31"

# GEE Resolution (CRS defined based on the first TerraClimate layer WGS84 )
res = 1000

# OpenLandMap Resolution 2km 1km, 250 m or 500 m
resOLM <- '1km'
#
#
#######################################################


# Load libraries ----
library(data.table)
library(raster)
library(terra)
library(sf)
library(rgee)
library(zen4R)
library(reticulate)

# Set working directory ----


setwd(wd)

# Upload own AOI shapefile ----
#AOI <- read_sf(AOI)
# convert AOI to a box polygon
#AOI <- st_as_sfc(st_bbox(AOI))
#AOI <- st_as_sf(AOI)




#List of covariates to prepare
# Mean annual temperature
# Total annual Precipitation
# Precipitation of wettest month
# Precipitation of driest month

# TAGEE 13 soil attributes (list below)

# MODIS EVI & NDVI

# Daytime temperature SD

# Landsat 8 RED and NIR standard deviation

# OpenLandMap 
# soil water content 0-10-30
# Potential FAPAR Monthly


# Multi-Scale Topographic Position Index

#Initialize GEE ----
ee_Initialize()

#Initial setup either convert shp to gee geometry or extract from UN 2020 map----

#Convert shp to gee geometry
#region <- sf_as_ee(AOI)
#region = region$geometry()

#Extract from UN 2020 map using ISO code ----
region <-ee$FeatureCollection("projects/digital-soil-mapping-gsp-fao/assets/UN_BORDERS/BNDA_CTY")%>%
  ee$FeatureCollection$filterMetadata('ISO3CD', 'equals', AOI)

AOI_shp <-ee_as_sf(region)
write_sf(AOI_shp, paste0('01-Data/',AOI,'.shp'))

region = region$geometry()

# Mean annual temperature (daytime) ----
# Go to https://code.earthengine.google.com/
# browse for the dataset you're interested in
# find and copy/paste the path  

image1 <- ee$ImageCollection("IDAHO_EPSCOR/TERRACLIMATE") %>%
  ee$ImageCollection$filterDate(start_T, end_T) %>%
  ee$ImageCollection$select("tmmx")%>%
  ee$ImageCollection$filterBounds(region)%>%
  ee$ImageCollection$toBands()

# from imagecollection to image
image2 <- ee$ImageCollection("IDAHO_EPSCOR/TERRACLIMATE") %>%
  ee$ImageCollection$filterDate(start_T, end_T) %>%
  ee$ImageCollection$select("tmmn")%>%
  ee$ImageCollection$filterBounds(region)%>%
  ee$ImageCollection$toBands()


image1 <- image1$multiply(0.1)
image2 <- image2$multiply(0.1)

diff <- image1$add(image2)
avT = diff$divide(2)
avT = avT$reduce(ee$Reducer$mean())

proj = avT$projection()$getInfo()

crs = proj$wkt

avT = avT$resample('bilinear')$reproject(
  crs= crs,
  scale= res)

avT =avT$clip(region)

# CTRL + shift + C to comment
avtr <- ee_as_raster(
  image = avT,
  scale= res,
  region = region,
  via = "drive"
)

writeRaster(avtr, '01-Data/covs/avtr.tif', overwrite=T)

# Total Annual Precipitation ----

image <- ee$ImageCollection("IDAHO_EPSCOR/TERRACLIMATE") %>%
  ee$ImageCollection$filterDate(start_T, end_T) %>%
  ee$ImageCollection$select("pr")%>%
  ee$ImageCollection$filterBounds(region)%>%
  ee$ImageCollection$sum()%>%
  ee$Image$toDouble()

Pr = image$resample('bilinear')$reproject(
  crs= crs,
  scale= res)

Pr =Pr$clip(region)

Prr <- ee_as_raster(
  image = Pr,
  scale= res,
  region = region,
  via = "drive"
)



writeRaster(Prr, '01-Data/covs/Prr.tif', overwrite=T)

# Precipitation of wettest month ----
image <- ee$ImageCollection("IDAHO_EPSCOR/TERRACLIMATE") %>%
  ee$ImageCollection$filterDate(start_T, end_T) %>%
  ee$ImageCollection$select("pr")%>%
  ee$ImageCollection$filterBounds(region)%>%
  ee$ImageCollection$toBands()



Prr_all = image$resample('bilinear')$reproject(
  crs= crs,
  scale= res)


Prr_allr <- ee_as_raster(
  image = Prr_all,
  scale= res,
  region = region,
  via = "drive"
)

sums <- cellStats(Prr_allr, 'sum')
wettest <- names(sums[sums ==max(sums)])
Prr_wet <- Prr_allr[[wettest]]

writeRaster(Prr_wet, '01-Data/covs/Prr_wet.tif', overwrite=T)

# Precipitation of driest month ----

dryest <- names(sums[sums ==min(sums)])
Prr_dry <- Prr_allr[[dryest]]

writeRaster(Prr_wet, '01-Data/covs/Prr_dry.tif', overwrite=T)


# Terrain attributes using TAGEE - 13 covariates ----
# Attribute	| Unit	| Description
# Elevation  |	meter	|Height of terrain above sea level
# Slope	degree	| Slope |  gradient
# Aspect |	degree |	Compass direction
# Hillshade	| dimensionless	|Brightness of the illuminated terrain
# Northness |	dimensionless |	Degree of orientation to North
# Eastness	| dimensionless |	Degree of orientation to East
# Horizontal curvature |	meter |	Curvature tangent to the contour line
# Vertical curvature |	meter	| Curvature tangent to the slope line
# Mean curvature |	meter	| Half-sum of the two orthogonal curvatures
# Minimal curvature	meter |	Lowest value of curvature
# Maximal curvature	meter |	Highest value of curvature
# Gaussian curvature	 | meter |	Product of maximal and minimal curvatures
# Shape Index	| dimensionless |	Continuous form of the Gaussian landform classification

# install TAGEE
system("pip install tagee")
# Import
TAGEE <- import("tagee")

image <- ee$Image("MERIT/DEM/v1_0_3") %>%
  ee$Image$clip(region)%>%
  ee$Image$toDouble()


image = image$resample('bilinear')$reproject(
  crs= crs,
  scale= res)

DEMAttributes = TAGEE$terrainAnalysis(image,region)
DEMAttributes =   DEMAttributes$unmask(0)


tageer <- ee_as_raster(
  image = DEMAttributes,
  scale= res,
  region = region,
  via = "drive"
)


plot(tageer)



writeRaster(tageer, '01-Data/covs/Terrain.tif', overwrite=T)

# EVI & NDVI ----
EVI <- ee$ImageCollection("MODIS/061/MOD13Q1") %>%
  ee$ImageCollection$filterDate(start_T, end_T) %>%
  ee$ImageCollection$select("EVI")%>%
  ee$ImageCollection$filterBounds(region)%>%
  ee$ImageCollection$toBands()

NDVI <- ee$ImageCollection("MODIS/061/MOD13Q1") %>%
  ee$ImageCollection$filterDate(start_T, end_T) %>%
  ee$ImageCollection$select("NDVI")%>%
  ee$ImageCollection$filterBounds(region)%>%
  ee$ImageCollection$toBands()

EVI = EVI$reduce(ee$Reducer$mean())

EVI = EVI$resample('bilinear')$reproject(
  crs= crs,
  scale= res)

NDVI = NDVI$reduce(ee$Reducer$mean())

NDVI = NDVI$resample('bilinear')$reproject(
  crs= crs,
  scale= res)

ndvir <- ee_as_raster(
  image = NDVI,
  scale= res,
  region = region,
  via = "drive"
)

evir <- ee_as_raster(
  image = EVI,
  scale= res,
  region = region,
  via = "drive"
)


writeRaster(ndvir, '01-Data/covs/NDVI.tif', overwrite=T)
writeRaster(evir, '01-Data/covs/EVI.tif', overwrite=T)

# Land daytime surface temperature (st.D) ----

image <- ee$ImageCollection("MODIS/061/MOD11A1") %>%
  ee$ImageCollection$filterDate("2018-01-01", "2018-12-31") %>%
  ee$ImageCollection$select("LST_Day_1km")%>%
  ee$ImageCollection$filterBounds(region)%>%
  ee$ImageCollection$toBands()

d_T = image$subtract(273.15)
sd_d_T = d_T$reduce(ee$Reducer$stdDev())

sd_d_T = sd_d_T$resample('bilinear')$reproject(
  crs= crs,
  scale= res)

# sd_d_Tr <- ee_as_raster(
#   image = sd_d_T,
#   scale= res,
#   region = region,
#   via = "drive"
# )
# 
# 
# writeRaster(sd_d_Tr, '01-Data/covs/sd_d_Tr.tif', overwrite=T)

# Landsat bands mean and sd ----
image <- ee$ImageCollection("LANDSAT/LC08/C02/T1_RT") %>%
  ee$ImageCollection$filterDate("2018-01-01", "2018-12-31") %>%
  ee$ImageCollection$select(c("B4"))%>%
  ee$ImageCollection$filterBounds(region)%>%
  ee$ImageCollection$toBands()


land_red = image$reduce(ee$Reducer$stdDev())

land_red = land_red$resample('bilinear')$reproject(
  crs= crs,
  scale= res)

land_sd_red <- ee_as_raster(
  image = land_red,
  scale= res,
  region = region,
  via = "drive"
)

writeRaster(land_sd_red, '01-Data/covs/land_sd_red.tif', overwrite=T)

image <- ee$ImageCollection("LANDSAT/LC08/C02/T1_RT") %>%
  ee$ImageCollection$filterDate("2018-01-01", "2018-12-31") %>%
  ee$ImageCollection$select(c("B5"))%>%
  ee$ImageCollection$filterBounds(region)%>%
  ee$ImageCollection$toBands()


land_nir = image$reduce(ee$Reducer$stdDev())
land_nir = land_nir$resample('bilinear')$reproject(
  crs= crs,
  scale= res)

land_nirr <- ee_as_raster(
  image = land_nir,
  scale= res,
  region = region,
  via = "drive"
)

writeRaster(land_nirr, '01-Data/covs/land_sd_nir.tif', overwrite=T)

# OpenLandMap soil water content 0-10-30 ----

image <- ee$Image("OpenLandMap/SOL/SOL_WATERCONTENT-33KPA_USDA-4B1C_M/v01") %>%
  ee$Image$select(c('b0','b10','b30'))%>%
  ee$Image$clip(region)

soil_wt = image$resample('bilinear')$reproject(
  crs= crs,
  scale= res)

soil_wtr <- ee_as_raster(
  image = soil_wt,
  scale= res,
  region = region,
  via = "drive"
)

#Harmonize to 0-30 depth with a weighted average
WeightedAverage<-function(r){return(r[[1]]*(1/30)+r[[2]]*(9/30)+r[[3]]*(20/30))}

soil_wtr<-overlay(soil_wtr,fun=WeightedAverage)

writeRaster(soil_wtr, '01-Data/covs/soil_wtr.tif', overwrite=T)

# OpenLandMap Potential FAPAR Monthly ----

image <- ee$Image("OpenLandMap/PNV/PNV_FAPAR_PROBA-V_D/v01") %>%
  ee$Image$select(c('jan','feb','mar','apr','may','jun','jul',
                    'aug','sep','oct','nov','dec' ))%>%
  ee$Image$clip(region)

fapar = image$resample('bilinear')$reproject(
  crs= crs,
  scale= res)

fapar=fapar$reduce(ee$Reducer$mean())

faparr <- ee_as_raster(
  image = fapar,
  scale= res,
  region = region,
  via = "drive"
)

writeRaster(faparr, '01-Data/covs/faparr_mean.tif', overwrite=T)



# Multi-Scale Topographic Position Index ----
image <- ee$Image("CSP/ERGo/1_0/Global/ALOS_mTPI") %>%
  ee$Image$select('AVE')%>%
  ee$Image$clip(region)

top_pos = image$resample('bilinear')$reproject(
  crs= crs,
  scale= res)

top_posr <- ee_as_raster(
  image = top_pos,
  scale= res,
  region = region,
  via = "drive"
)

writeRaster(top_posr, '01-Data/covs/top_posr.tif', overwrite=T)


# Zenodo ----
#######################################################
#
#  Process and download topographic 
#  OpenLandMap
#  from zenodo to R 
#
#
#######################################################



# Get links for the OpenLandMap topographic attributes
# to download from Zenodo

#  #instantiate Zen4R client
#  zenodo <- ZenodoManager$new()
# 
#  # Get file record
#  my_rec <- zenodo$getRecordByDOI("10.5281/zenodo.1447210")
# 
#  sel.tif = my_rec$files
# 
#  # Extract list of links
#  links <- data.frame()
#  for (i in 1:length(sel.tif)){
# 
#    x<-as.data.frame(sel.tif[[i]][["links"]][["download"]])
#      links <- rbind(links,x)
# 
# 
# }
# 
# names(links) <-'Links'
# 
# # Selection of topographic attributes
# seltop <- c('slope', 'twi', 'vbf','_curvature','downlslope.curvature','dvm2','dvm','mrn','tpi')
# # Download global layers (to be done once) ---
# 
# for (i in unique(seltop)){
# link <- links[grep(i, links$Links),]
# link <- link[grep(resOLM, link)]
# 
# 
# download.file(link, paste0(output_dir, 'olm_',i,'_',resOLM,'.tif'),mode = "wb")
# }

# Clip and store covariates in working directory
AOI <- vect(AOI)

files <- list.files(path = output_dir, pattern = resOLM, full.names = T)
covs <- stack(files)

covs <- rast(covs)

covs <- crop(covs, AOI)
covs <- mask(covs, AOI)


#Use one rgee raster to harmonize the covs
rgee <-rast('01-Data/covs/Prr.tif')
covs <- resample(covs, rgee)

writeRaster(covs, '01-Data/covs/olm_covs.tif', overwrite=T)  


# Upload the raster stack to gee through the code editor https://code.earthengine.google.com/
# create image from asset
# 1. Create a folder
# Change path asset according to your specific user
# Obtain your asset home name

olm <-ee$Image('users/IsaLuotto/olm_covs')
###########################################################################
# Export PCs based on Principle Component Analysis ----

# Stack bands 
#avT,Pr,Prr_all,DEMAttributes,EVI,NDVI,sd_d_T,land_red,land_nir,soil_wt,fapar,top_pos
SG <-
  avT$addBands(Pr)$addBands(Prr_all)$addBands(DEMAttributes)$addBands(EVI)

SG <-SG$addBands(NDVI)$addBands(land_red)$addBands(sd_d_T)$addBands(land_nir)

SG <-SG$addBands(fapar)$addBands(soil_wt)$addBands(top_pos)$addBands(olm)




class(SG)

inputBandNames <- SG$bandNames()$getInfo()
print(inputBandNames)

dimOne <- length(inputBandNames)
cat("Number of input bands:", dimOne)

# Calculate scale standardize each band to mean=0, s.d.=1. ----
scale <- SG$select("mean")$projection()$nominalScale()
cat("Nominal scale: ", scale$getInfo())

SGmean <- SG$reduceRegion(ee$Reducer$mean(),
                          geometry = region, scale = scale, bestEffort = TRUE)
head(SGmean$getInfo(),3) # an example of the means

SGsd <- SG$reduceRegion(ee$Reducer$stdDev(),
                        geometry = region, scale = scale, bestEffort = TRUE)
head(SGsd$getInfo(),3)

# saveRDS(as.vector(SGmean$getInfo()), file = "./inputBandMeans.rds")
# saveRDS(as.vector(SGsd$getInfo()), file = "./inputBandSDs.rds")

SGmean.img <- ee$Image$constant(SGmean$values(inputBandNames))
SGsd.img <- ee$Image$constant(SGsd$values(inputBandNames))

#Standardize
SGstd <- SG$subtract(SGmean.img)
SGstd <- SGstd$divide(SGsd.img)


SGstd.minMax <- SGstd$reduceRegion(ee$Reducer$minMax(),
                                   geometry = region, scale = scale,
                                   maxPixels = 1e9, bestEffort = TRUE)
minMaxNames <- names(SGstd.minMax$getInfo())
minMaxVals <- SGstd.minMax$values()$getInfo()
# per property min/max
head(data.frame(property_depth_q=minMaxNames, value=minMaxVals), 12)

# overall min/max
print(c(min(minMaxVals), max(minMaxVals)) )

# convert image to an array of pixels, for matrix calculations
# dimensions are N x P; i.e., pixels x bands
arrays <- SGstd$toArray()


# Compute the covariance of the bands within the region.
covar <- arrays$reduceRegion(
  ee$Reducer$centeredCovariance(),
  geometry = region, scale = scale,
  maxPixels = 1e6,
  bestEffort = TRUE
)


# Get the covariance result and cast to an array.
# This represents the band-to-band covariance within the region.
covarArray <- ee$Array(covar$get('array'))
# note we know the dimensions from the inputs
# Perform an eigen analysis and slice apart the values and vectors.
eigens <- covarArray$eigen()
# the first item of each slice (PC) is the corresponding eigenvalue
# the remaining items are the eigenvalues (rotations) for that PC

# by removing the first axis (eigenvalues) and converting to a vector
# array$slice(axis=0, start=0, end=null, step=1)
# here we only have one axis, indexed by the PC
eigenValues <- eigens$slice(1L, 0L, 1L)
cat('Eigenvalues:')
## Eigenvalues:
print(eigenValues.vect <- unlist(eigenValues$getInfo()))

# compute and show proportional eigenvalues
eigenValuesProportion <-
  round(100*(eigenValues.vect/sum(eigenValues.vect)),2)
cat('PCs percent of variance explained:')
## PCs percent of variance explained:
print(eigenValuesProportion)

plot(eigenValuesProportion, type="h", xlab="PC",
     ylab="% of variance explained",
     main="Standardized PCA")

evsum <- cumsum(eigenValuesProportion)
cat('PCs percent of variance explained, cumulative sum:')
## PCs percent of variance explained, cumulative sum:
print(round(evsum,1))

cat(npc95 <- which(evsum > 95)[1],
    "PCs are needed to explain 95% of the variance")

#saveRDS(eigenValues.vect, file = "./eigenValuesVector.rds")


# The eigenvectors (rotations); this is a PxP matrix with eigenvectors in rows.
eigenVectors <- eigens$slice(1L, 1L)
# show the first few rotations
cat('Eigenvectors 1--3:')
## Eigenvectors 1--3:
print(data.frame(band=inputBandNames,
                 rotation1 = eigenVectors$getInfo()[[1]],
                 rotation2 = eigenVectors$getInfo()[[2]],
                 rotation3 = eigenVectors$getInfo()[[3]]
))

#export the eigenvectors ----
eVm <- matrix(unlist(eigenVectors$getInfo()), byrow = TRUE, nrow = dimOne)
#saveRDS(eVm, file = "./eigenvectorMatrix.rds")

arrayImage <- arrays$toArray(1L)
PCsMatrix <- ee$Image(eigenVectors)$matrixMultiply(arrayImage)

# arrayProject: "Projects the array in each pixel to a lower dimensional #
#space by specifying the axes to retain"
# arrayFlatten: "Converts a single band image of equal-shape
# multidimensional pixels
# to an image of scalar pixels,
# with one band for each element of the array."
PCbandNames <- as.list(paste0('PC', seq(1L:dimOne)))
PCs <- PCsMatrix$arrayProject(list(0L))$arrayFlatten(
  list(PCbandNames)
)

PCs95 <- PCs$select(0L:(npc95-1L)) # indexing starts from 0
PCs95$bandNames()$getInfo()

# Export PCs as raster stack ----
PCAs_covs <- ee_as_raster(
  image = PCs95,
  scale= res,
  region = region,
  via = "drive"
)



writeRaster(PCAs_covs, '02-Outputs/PCA_covariates.tif', overwrite= T)

