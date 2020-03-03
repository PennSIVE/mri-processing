# 
# Neuroimaging pre-processing and visualization 
# Kelly Clark & Melissa Martin
#
# 

# note: order of imported libraries matters
# "You have loaded oro.nifti after extrantsr (either directly or from another package) - this is likely to cause problems with certain functions on antsImage types, such as origin.
# if you need functions from both extrantsr and oro.nifti, please load oro.nifti first, then extrantsr"
library(neurobase)
library(oro.dicom)
library(oro.nifti)
library(ANTsR)
library(extrantsr)
library(WhiteStripe)

baselineDCMSource <- "/baseline"
followupDCMSource <- "/followup"
Processed_dir_path <- "/processed"
ws_type <- Sys.getenv("WS_TYPE")
stopifnot(ws_type == "T1" || ws_type == "T2")

#read in DICOM series 
print(paste0("Now reading in dicom images"))
baseline_img <<- readDICOM(baselineDCMSource)
followup_img <<- readDICOM(followupDCMSource)


##convert dicom to nifti and write nifti to file
print(paste0("Dicom images have been read in and are now being converted to NIFTI images"))
baseline_nifti <<- dicom2nifti(baseline_img)
followup_nifti <<- dicom2nifti(followup_img)
#writenii(baseline_nifti, paste0(Processed_dir_path,"/Baseline.nii.gz"))
#writenii(followup_nifti, paste0(Processed_dir_path,"/FollowUp.nii.gz"))

#ANTS N4 correction
print(paste0("Now N4 correcting nifti images"))
baseline_n4<<- bias_correct(baseline_nifti, correction = "N4")
followup_n4<<- bias_correct(followup_nifti, correction = "N4")
#writenii(baseline_n4, paste0(Processed_dir_path,"/Baseline_N4.nii.gz"))
writenii(followup_n4, paste0(Processed_dir_path,"/FollowUp_N4.nii.gz"))

#ANTS registration of FollowUp to Baseline
# print(paste0("Now registering baseline image to follow-up image"))
baseline_to_followup<<- antsRegistration(fixed=oro2ants(followup_n4), moving=oro2ants(baseline_n4), 
                                        typeofTransform=c("Rigid"))
baseline_reg<<- antsApplyTransforms(fixed=oro2ants(followup_n4), moving=oro2ants(baseline_n4),
                                  transformlist = baseline_to_followup$fwdtransforms,
                                  interpolator =c("WelchWindowedSinc"))
antsImageWrite(baseline_reg, paste0(Processed_dir_path,"/baselineN4_to_followupN4_reg.nii.gz"))

#WhiteStripe
print(paste0("Finished registration, now performing WhiteStripe normalization"))
baseline_ind<<- whitestripe(ants2oro(baseline_reg), ws_type)
baseline_ws<<- whitestripe_norm(ants2oro(baseline_reg), baseline_ind$whitestripe.ind)
#writenii(baseline_ws, paste0(Processed_dir_path,"/Baseline_WS.nii.gz"))
  
followup_ind<<-whitestripe(followup_n4, ws_type)
followup_ws<<-whitestripe_norm(followup_n4, followup_ind$whitestripe.ind)
#writenii(followup_ws, paste0(Processed_dir_path,"/Followup_WS.nii.gz"))
difference<<- (followup_ws - baseline_ws)
writenii(difference, paste0(Processed_dir_path,"/difference_WS.nii.gz"))
print(paste0("Finished WhiteStripe normalization, opening image in ITK-SNAP"))


#### ~5.5 minute run time if running on Desktop and imgs are local


