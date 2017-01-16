# Author: Mateusz Mika - IBM 2017

packages <- function(x) {
  x <- as.character(match.call()[[2]])
  if (!require(x,character.only=TRUE)){
    install.packages(pkgs=x,repos="http://cran.r-project.org")
    require(x,character.only=TRUE)
  }
}
packages(httr)

asDate <- function(inputDate){
	tmpDate <- strsplit(inputDate," ")[[1]]
	outputDate <- paste(tmpDate[6],grep(tmpDate[2],month.abb),tmpDate[3],sep="-")
	return(as.Date(outputDate))
}
fbApi <- function(id, destination, token, limit, fields, after){
	apiCall <- paste0("https://graph.facebook.com/",id,"/",destination,"?date_format=U&access_token=",token)
	apiCall <- paste(apiCall,limit,fields,sep="&")
	if(after != "") apiCall <- paste0(apiCall,"&after=",after)
	apiResponse <- content( GET(apiCall) )
	if( "error" %in% names(apiResponse) ){
		warning(paste0("Facebook error: ",apiResponse[["error"]][["message"]]))
		return("error")
	}
	return(apiResponse)
}
err <- FALSE
accessToken <- "%%accessToken%%"
pageID <- "%%pageID%%"
fromDate <- asDate("%%dateFrom%%")
toDate <- asDate("%%dateTo%%")
if( is.na(fromDate) || is.na(toDate) ){
	warning('There was a problem with Date. Check "month.abb" constant.')
	err <- TRUE
} else if (fromDate > toDate){
	tmpDate <- fromDate
	fromDate <- toDate
	toDate <- tmpDate
}
#available values for dateTypeControl are: "Creation", "Update", "CreationAndUpdate"
whichDate <- "%%dateTypeControl%%"
maxPhotos <- as.integer("%%maxAmount%%")
if( is.na(maxPhotos) ) maxPhotos <- as.integer(-1)
photosFromComments <- %%photosFromComments%%
checkAllPosts <- %%checkAllPosts%%
inputPostIDs <- strsplit("%%postIDs%%","[^[:digit:]_]+")[[1]]
if( length(inputPostIDs) > 0 ){
	if( nchar(inputPostIDs)[1]==0 ){
		if( length(inputPostIDs) == 1) inputPostIDs <- c()
		else inputPostIDs <- inputPostIDs[2:length(inputPostIDs)]
	}
}
#available values for posterControl are: "Admin","User","AdminAndUser"
whichPosters <- "%%posterControl%%"

apiResponse <- content(GET(paste0("https://graph.facebook.com/",pageID,"?access_token=",accessToken)))
adminName <- apiResponse[["name"]]
adminID <- apiResponse[["id"]]

outParentIDs <- c()
outParentNames <- c()
outParentDescriptions <- c()
outParentUpdated <- c()
outParentCreated <- c()
outPhotoIDs <- c()
outPhotoURLs <- c()
outUserIDs <- c()
outUserNames <- c()
outIndirectLinks <- c()
outPhotoDescriptions <- c()
outPhotoBackdated <- c()
outPhotoUpdated <- c()
outPhotoCreated <- c()
counter <- 0
albumIDs <- c()
albumNames <- c()
albumDescriptions <- c()
albumUpdated <- c()
albumCreated <- c()
postIDs <- inputPostIDs
postDescriptions <- c()
postUpdated <- c()
postCreated <- c()

after <- ""
fields <- "fields=id,photo_count,updated_time,created_time,name,description"

while( counter < 100 && !err){
	apiResponse <- fbApi(pageID,"albums",accessToken,"limit=100",fields,after)
	if ( length(apiResponse) == 1 ) if( apiResponse == "error" ){
		err = TRUE
		break
	}
	if( is.null(apiResponse[["paging"]]) ) break
	for(album in apiResponse[["data"]]){
		updated <- as.Date.POSIXct(album[["updated_time"]])
		created <- as.Date.POSIXct(album[["created_time"]])
		if( album[["photo_count"]] > 0 && updated >= fromDate && created <= toDate ){
			albumIDs <- c(albumIDs,album[["id"]])
			albumNames <- c(albumNames,album[["name"]])
			if( !is.null(album[["description"]]) ){
				albumDescriptions <- c(albumDescriptions,album[["description"]])
			} else albumDescriptions <- c(albumDescriptions,"")
			albumUpdated <- c(albumUpdated,format(updated,"%Y-%m-%d"))
			albumCreated <- c(albumCreated,format(created,"%Y-%m-%d"))
		}
	}
	if("next" %in% names(apiResponse[["paging"]])){
		after <- apiResponse[["paging"]][["cursors"]][["after"]]
		counter <- counter + 1
	} else break
}
album <- 1
after <- ""
fields <- "fields=id,created_time,updated_time,name,backdated_time,backdated_time_granularity,images.fields(source),link"

for(albumID in albumIDs){
	counter <- 0
	while( counter < 100 && (maxPhotos > 0 || maxPhotos == -1) && !err){
		apiResponse <- fbApi(albumID,"photos",accessToken,"limit=100",fields,after)
		if ( length(apiResponse) == 1 ) if( apiResponse == "error" ){
			err = TRUE
			break
		}
		if( is.null(apiResponse[["paging"]]) ) break
		for(photo in apiResponse[["data"]]){
			if( maxPhotos > 0 || maxPhotos == -1 ){
				photoUpdated <- as.Date.POSIXct(photo[["updated_time"]])
				photoCreated <- as.Date.POSIXct(photo[["created_time"]])
				if( (photoUpdated >= fromDate && photoUpdated <= toDate && grepl("Update",whichDate)) ||
					(photoCreated >= fromDate && photoCreated <= toDate && grepl("Creation",whichDate)) ){
					if( grepl("Admin",whichPosters) ){
						outParentIDs <- c(outParentIDs,albumIDs[album])
						outParentNames <- c(outParentNames,albumNames[album])
						outParentDescriptions <- c(outParentDescriptions,albumDescriptions[album])
						outParentUpdated <- c(outParentUpdated,albumUpdated[album])
						outParentCreated <- c(outParentCreated,albumCreated[album])
						outPhotoIDs <- c(outPhotoIDs,photo[["id"]])
						outPhotoURLs <- c(outPhotoURLs,photo[["images"]][[1]][["source"]])
						outUserIDs <- c(outUserIDs,adminID)
						outUserNames <- c(outUserNames,adminName)
						outIndirectLinks <- c(outIndirectLinks,photo[["link"]])
						if(!is.null(photo[["name"]])){
							outPhotoDescriptions <- c(outPhotoDescriptions,photo[["name"]])
						} else outPhotoDescriptions <- c(outPhotoDescriptions,"")
						if(!is.null(photo[["backdated_time"]])){
							photoBackdated <- as.Date.POSIXct(photo[["backdated_time"]])
							if(photo[["backdated_time_granularity"]]=="year"){
								photoBackdated <- format(photoBackdated,"%Y")
							} else if(photo[["backdated_time_granularity"]]=="month"){
								photoBackdated <- format(photoBackdated,"%Y-%m")
							} else photoBackdated <- format(photoBackdated,"%Y-%m-%d")
							outPhotoBackdated <- c(outPhotoBackdated,photoBackdated)
						} else outPhotoBackdated <- c(outPhotoBackdated,"")
						outPhotoUpdated <- c(outPhotoUpdated,format(photoUpdated,"%Y-%m-%d"))
						outPhotoCreated <- c(outPhotoCreated,format(photoCreated,"%Y-%m-%d"))
						if(maxPhotos > 0) maxPhotos <- maxPhotos-1
					}
					if( photosFromComments && (length(inputPostIDs) < 1) && !checkAllPosts ){
						postIDs <- c(postIDs,photo[["id"]])
						postDescriptions <- c(postDescriptions,photo[["name"]])
						postUpdated <- c(postUpdated,format(photoUpdated,"%Y-%m-%d"))
						postCreated <- c(postCreated,format(photoCreated,"%Y-%m-%d"))
					}
				}
				if( photosFromComments && (length(inputPostIDs) < 1) && checkAllPosts ){
					postIDs <- c(postIDs,photo[["id"]])
					postDescriptions <- c(postDescriptions,photo[["name"]])
					postUpdated <- c(postUpdated,format(photoUpdated,"%Y-%m-%d"))
					postCreated <- c(postCreated,format(photoCreated,"%Y-%m-%d"))
				}
			} else break
		}
		if("next" %in% names(apiResponse[["paging"]])){
			after <- apiResponse[["paging"]][["cursors"]][["after"]]
			counter <- counter + 1
		} else break
	}
	album <- album + 1
}
post <- 1
after <- ""
fields <- "fields=id,created_time,from,message,attachment.fields(type,url,media)"
for(postID in postIDs){
	counter <- 0
	while( counter < 100 && (maxPhotos > 0 || maxPhotos == -1) && !err ){
		apiResponse <- fbApi(postID,"comments",accessToken,"limit=500&filter=stream&order=reverse_chronological",fields,after)
		if ( length(apiResponse) == 1 ) if( apiResponse == "error" ){
			err = TRUE
			break
		}
		if( is.null(apiResponse[["paging"]]) ) break
		for(comm in apiResponse[["data"]]){
			if( maxPhotos > 0 || maxPhotos == -1 ){
				commentCreated <- as.Date.POSIXct(comm[["created_time"]])
				if( "attachment" %in% names(comm) && commentCreated >= fromDate && commentCreated <= toDate &&
					(grepl("photo",comm[["attachment"]][["type"]]) || grepl("image",comm[["attachment"]][["type"]])) &&
					("Admin" == whichPosters && comm[["from"]][["id"]] == adminID) || ("User" == whichPosters && comm[["from"]][["id"]] != adminID) || "AdminAndUser" == whichPosters){
					outParentIDs <- c(outParentIDs,postID)
					outParentNames <- c(outParentNames,"")
					outParentDescriptions <- c(outParentDescriptions,postDescriptions[post])
					outParentUpdated <- c(outParentUpdated,postUpdated[post])
					outParentCreated <- c(outParentCreated,postCreated[post])
					outPhotoIDs <- c(outPhotoIDs,comm[["id"]])
					outPhotoURLs <- c(outPhotoURLs,comm[["attachment"]][["media"]][["image"]][["src"]])
					outIndirectLinks <- c(outIndirectLinks,comm[["attachment"]][["url"]])
					outUserIDs <- c(outUserIDs,comm[["from"]][["id"]])
					outUserNames <- c(outUserNames,comm[["from"]][["name"]])
					outPhotoDescriptions <- c(outPhotoDescriptions,comm[["message"]])
					outPhotoBackdated <- c(outPhotoBackdated,"")
					outPhotoUpdated <- c(outPhotoUpdated,"")
					outPhotoCreated <- c(outPhotoCreated,format(commentCreated,"%Y-%m-%d"))
					if(maxPhotos > 0) maxPhotos <- maxPhotos-1
				}
			} else break
		}
		if("next" %in% names(apiResponse[["paging"]])){
			after <- apiResponse[["paging"]][["cursors"]][["after"]]
			counter <- counter + 1
		} else break
	}
	post <- post + 1
}
if( !is.null(outPhotoURLs) ){
	outPhotoDescriptions <- gsub("\\n","<newline>",outPhotoDescriptions)
	modelerData <- data.frame(outPhotoIDs,outPhotoURLs,outPhotoDescriptions,outPhotoCreated,outPhotoUpdated,
								outPhotoBackdated,outUserIDs,outUserNames,outParentIDs,outParentNames,
								outParentDescriptions,outParentCreated,outParentUpdated,outIndirectLinks)

	var1 <- c(fieldName="ID", fieldLabel="", fieldStorage="string", fieldMeasure="", fieldFormat="", fieldRole="")
	var2 <- c(fieldName="URL", fieldLabel="", fieldStorage="string", fieldMeasure="", fieldFormat="", fieldRole="")
	var3 <- c(fieldName="Description", fieldLabel="", fieldStorage="string", fieldMeasure="", fieldFormat="", fieldRole="")
	var4 <- c(fieldName="CreatedDate", fieldLabel="", fieldStorage="string", fieldMeasure="", fieldFormat="", fieldRole="")
	var5 <- c(fieldName="UpdatedDate", fieldLabel="", fieldStorage="string", fieldMeasure="", fieldFormat="", fieldRole="")
	var6 <- c(fieldName="BackdatedDate", fieldLabel="", fieldStorage="string", fieldMeasure="", fieldFormat="", fieldRole="")
	var7 <- c(fieldName="UserID", fieldLabel="", fieldStorage="string", fieldMeasure="", fieldFormat="", fieldRole="")
	var8 <- c(fieldName="UserName", fieldLabel="", fieldStorage="string", fieldMeasure="", fieldFormat="", fieldRole="")
	var9 <- c(fieldName="ParentID", fieldLabel="", fieldStorage="string", fieldMeasure="", fieldFormat="", fieldRole="")
	var10 <- c(fieldName="ParentName", fieldLabel="", fieldStorage="string", fieldMeasure="", fieldFormat="", fieldRole="")
	var11 <- c(fieldName="ParentDescription", fieldLabel="", fieldStorage="string", fieldMeasure="", fieldFormat="", fieldRole="")
	var12 <- c(fieldName="ParentCreationDate", fieldLabel="", fieldStorage="string", fieldMeasure="", fieldFormat="", fieldRole="")
	var13 <- c(fieldName="ParentUpdatedDate", fieldLabel="", fieldStorage="string", fieldMeasure="", fieldFormat="", fieldRole="")
	var14 <- c(fieldName="IndirectLink", fieldLabel="", fieldStorage="string", fieldMeasure="", fieldFormat="", fieldRole="")
	
	modelerDataModel <- data.frame(var1,var2,var3,var4,var5,var6,var7,var8,var9,var10,var11,var12,var13,var14)
} else if (!err) warning("Did not found any photos")
