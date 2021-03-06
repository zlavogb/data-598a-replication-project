
# CODE TO CALCULATE COUNTRY-SPECIFIC CHANGE IN TEMPERATURE UNDER RCP8.5, AND UNDER DIFFERENT GLOBAL AVERAGE WARMINGS (SO WE CAN CALCULATE DAMAGE FUNCTION)
#   We are using CMIP5 RCP8.5 ensemble mean data from here: http://climexp.knmi.nl/plot_atlas_form.py 
# @knitr gettemp
rm(list=ls())

library(pacman)
p_load(ncdf4, maptools,maps,raster,rgdal,here)
"%&%"<-function(x,y)paste(x,y,sep="")

cty=readOGR(dsn="./data/input/shape",layer="country")  #shapefile of global countries, as provided by ESRI distribution
cty1 <- cty[cty@data[,3]!="Antarctica" & cty@data[,3]!="Svalbard",]  #drop antarctica

#########################################################################################
# Read in CMIP5 global temperature projections, using data from here: http://climexp.knmi.nl/plot_atlas_form.py 
#  these are model ensemble averages, giving temperature changes 2080-2100 minus 1986-2005
nc <- nc_open("data/input/CCprojections/diff_tas_Amon_modmean_rcp85_000_2081-2100_minus_1986-2005_mon1_ave12_withsd.nc")
tmp <- ncvar_get(nc,"diff")
r <- raster(aperm(tmp[c(73:144,1:72),72:1],c(2,1)),xmn=-180,xmx=180,ymn=-90,ymx=90)
#plot(r)
#map(,add=T)

#population data from Gridded Population of the World dataset
pop = readAsciiGrid("data/input/populationData/glp00ag30.asc") #check out ?SpatialGridDataFrame, which is the class of the thing that is getting read in

pop=as.matrix(pop)
pop=raster(t(pop),xmn=-180,xmx=180,ymn=-58,ymx=85)
rr <- crop(r, pop)  #crop temp raster to size of population raster
pw <- aggregate(pop,fact=5)  #aggregate population raster up to 2.5deg, the resolution of the downloaded GCM data

cc <- extract(r,cty1,small=T,progress="text")  # returns a list where each element is the cell numbers in the pop raster that are covered by a given country.  
pp <- extract(pw,cty1,small=T,progress="text")

wtmn <- function(x,y) {if (length(x)>1 & sum(y)!=0) {weighted.mean(x,y)} else {mean(x)}}  # if country only covered by one cell, or if no population in aggregated grids, just report value of delta T in that cell
Tchg <- mapply(wtmn,cc,pp)  #this gives you the country-specific population-weighted temperature change


# Now calculate a vector of "conversion factors" that translate global mean temp into country specific temperatures:  this is just the ratio of pop-weighted country-specific changes to global mean change in RCP8.5
# This then allows us to calculate damages for various levels of warming
y <- init(r,v='y')
y <- cos(y*pi/180)  #cosine of latitude, converted to radians.  
y <- y/cellStats(y,'sum')  #make weights sum to 1 to make weighting matrix
tc <- cellStats(y*r,'sum')  #this is the global weighted mean temperature change
Tconv <- Tchg/tc  #"conversion factors":  i.e. what you multiply the global mean temp by to get the country-level change in temp.  again, this is based only on RCP8.5 ensemble mean 

out <- data.frame(cty1@data[,1:3],Tchg,Tconv)
write.csv(out,file="data/input/CCprojections/CountryTempChange_RCP85.csv",row.names=F)


